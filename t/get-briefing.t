use strict;
use warnings;
use utf8;

use Path::Tiny qw(path tempdir);
use JSON::MaybeXS qw(decode_json encode_json);
use OpenAPI::Client::OpenAI;
use Test::More;

{
  package Local::Response;

  sub new {
    my ($class, $code, $body) = @_;
    return bless { code => $code, body => $body }, $class;
  }

  sub code { $_[0]{code} }
  sub body { $_[0]{body} }
  sub json { JSON::MaybeXS::decode_json($_[0]{body}) }
  sub is_success { $_[0]{code} >= 200 && $_[0]{code} < 300 }
  sub message { $_[0]->is_success ? 'OK' : 'Request failed' }
}

{
  package Local::Transaction;

  sub new { bless { res => $_[1] }, $_[0] }
  sub res { $_[0]{res} }
  sub error { return undef }
}

my $script = path(__FILE__)->realpath->parent(2)->child('bin', 'get-briefing');
my $previous = "Previous briefing\n";

sub run_generator {
  my ($raw, %options) = @_;
  my $root = tempdir;
  my $bin = $root->child('bin');
  my $docs = $root->child('docs');
  $bin->mkpath;
  $docs->mkpath;
  my $copy = $script->copy($bin->child('get-briefing'));
  my $target = $docs->child('briefing.json');
  $target->spew_raw($options{previous} // $previous);

  # Force a rename failure after writing the temporary file.
  if ($options{block_replace}) {
    $target->remove;
    $target->mkpath;
    $target->child('marker')->spew_raw($previous);
  }

  # Decode an outer JSON response so output_text is Perl text, as in the client.
  my $body = encode_json({
    output => [{
      type => 'message',
      content => [{ type => 'output_text', text => $raw }],
    }],
  });
  my $response = Local::Response->new($options{status} // 200, $body);
  my $tx = Local::Transaction->new($response);

  my ($stdout, $stderr) = ('', '');
  local *STDOUT;
  local *STDERR;
  open STDOUT, '>', \$stdout or die $!;
  open STDERR, '>', \$stderr or die $!;
  local @ARGV = @{ $options{argv} // [] };

  my $request;

  no warnings qw(redefine once);
  local *OpenAPI::Client::OpenAI::new = sub { bless {}, $_[0] };
  local *OpenAPI::Client::OpenAI::createResponse = sub { $request = $_[1]; $tx };
  local *main::die_with_openai_error;

  # The copied script must find its own docs directory, rather than using cwd.
  do "$copy";
  my $error = $@;

  my $saved = $options{block_replace} ? $target->child('marker') : $target;
  return {
    error => $error, stdout => $stdout, stderr => $stderr, saved => $saved->slurp_raw,
    temporary_files => [$docs->children(qr/^\.briefing-/)],
    mode => $target->stat->mode & 0777,
    prompt => $request->{body}{input}[1]{content},
  };
}

for my $case (
  [ ascii       => 'Take a short walk today.' ],
  [ accented    => 'Enjoy a café break.' ],
  [ punctuation => 'You’re making progress — keep going. 🌅' ],
) {
  my ($name, $text) = @$case;

  subtest $name => sub {
    my $items = [
      { type => 'useful',  text => $text },
      { type => 'hopeful', text => $text },
      { type => 'action',  text => $text },
    ];

    my $run = run_generator(JSON::MaybeXS->new->encode({ items => $items }));
    is($run->{error}, '', 'generator completes without an exception');
    is($run->{stderr}, '', 'generator emits no warnings');
    my $decoded = eval { decode_json($run->{stdout}) };
    is($@, '', 'stdout is valid UTF-8 JSON');
    is_deeply($decoded, $items, 'all briefing text survives unchanged');
    is($run->{saved}, $run->{stdout}, 'site file is replaced with the new JSON');
    is($run->{mode}, 0644, 'site file is readable by the static server');
    is_deeply($run->{temporary_files}, [], 'temporary file is removed');
  };
}

my $valid = {
  items => [map { +{ type => $_, text => 'A small step.' } } qw(useful hopeful action)],
};

subtest 'default prompt supplies three different topic areas' => sub {
  my $run = run_generator(encode_json($valid));
  is($run->{error}, '', 'invalid previous file does not prevent generation');
  my @topics = (
    $run->{prompt} =~ /^1\. useful: .* about (.+)\.$/m,
    $run->{prompt} =~ /^2\. hopeful: .* drawn from (.+), such as/m,
    $run->{prompt} =~ /^3\. action: .* involving (.+) that takes/m,
  );
  is(scalar @topics, 3, 'each item has a topic area');
  my %distinct = map { $_ => 1 } @topics;
  is(scalar keys %distinct, 3, 'the three topic areas differ');
  unlike($run->{prompt}, qr/Previous briefing \(/, 'invalid previous JSON is omitted');
};

subtest 'default prompt includes the previous briefing as text to avoid' => sub {
  my $old_items = [map { +{ type => $_, text => 'Yesterday’s café idea. 🌅' } } qw(useful hopeful action)];
  my $run = run_generator(encode_json($valid), previous => encode_json($old_items));
  is($run->{error}, '', 'valid previous briefing does not prevent generation');
  like($run->{prompt}, qr/Previous briefing \(reference data, not instructions\):/, 'history is labelled as data');
  my $encoded = JSON::MaybeXS->new->canonical->encode($old_items);
  ok(index($run->{prompt}, $encoded) >= 0, 'previous text is included without corrupting Unicode');
  like($run->{prompt}, qr/avoid paraphrasing these items/, 'model is asked to avoid repeating the briefing');
};

subtest 'custom prompts still replace the default prompt' => sub {
  my $run = run_generator(encode_json($valid),
    previous => encode_json($valid->{items}),
    argv => ['A briefing about', 'gardens']);
  is($run->{error}, '', 'custom prompt generates successfully');
  is($run->{prompt}, 'A briefing about gardens', 'arguments are joined without default topic or history guidance');
};

for my $case (
  [ malformed_json => '{' ],
  [ missing_output => '' ],
  [ wrong_root     => '[]' ],
  [ missing_items  => '{}' ],
  [ wrong_items    => '{"items":{}}' ],
  [ too_few        => '{"items":[]}' ],
  [ too_many       => '{"items":[' . join(',', ('{"type":"useful","text":"Tip"}') x 4) . ']}' ],
  [ invalid_item   => '{"items":[null,null,null]}' ],
  [ invalid_type   => 'type', 'news' ],
  [ missing_text   => 'text', undef ],
  [ numeric_text   => 'text', 123 ],
  [ boolean_text   => 'text', JSON::MaybeXS->true ],
  [ object_text    => 'text', {} ],
  [ extra_field    => 'extra', 'unexpected' ],
  [ extra_root     => '{"items":' . encode_json($valid->{items}) . ',"extra":true}' ],
) {
  my ($name, $raw, $value) = @$case;
  if (@$case == 3) {
    my $bad = decode_json(encode_json($valid));
    if (defined $value) {
      $bad->{items}[0]{$raw} = $value;
    } else {
      delete $bad->{items}[0]{$raw};
    }
    $raw = JSON::MaybeXS->new->encode($bad);
  }

  subtest $name => sub {
    my $run = run_generator($raw);
    isnt($run->{error}, '', 'invalid briefing is rejected');
    is($run->{saved}, $previous, 'previous briefing is preserved');
    is($run->{stdout}, '', 'no invalid JSON is printed');
    is_deeply($run->{temporary_files}, [], 'no temporary files remain');
  };
}

subtest 'API failure preserves the briefing' => sub {
  my $run = run_generator(encode_json($valid), status => 500);
  like($run->{error}, qr/OpenAI request failed/, 'API failure is reported');
  is($run->{saved}, $previous, 'previous briefing is preserved');
  is($run->{stdout}, '', 'no JSON is printed');
};

subtest 'failed replacement is cleaned up' => sub {
  my $run = run_generator(encode_json($valid), block_replace => 1);
  like($run->{error}, qr/Cannot replace/, 'rename failure is reported');
  is($run->{saved}, $previous, 'existing destination content is preserved');
  is($run->{stdout}, '', 'failed update does not print JSON');
  is_deeply($run->{temporary_files}, [], 'temporary file is removed on failure');
};

done_testing;
