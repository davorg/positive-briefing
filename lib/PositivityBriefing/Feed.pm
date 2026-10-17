package PositivityBriefing::Feed;

use v5.36;
use Exporter 'import';
use Digest::SHA qw(sha256_hex);
use DateTime;
use Encode qw(encode);
use HTML::Entities qw(encode_entities);
use JSON::MaybeXS;
use XML::Feed;
use XML::Feed::Entry;

our @EXPORT_OK = qw(build_feed);

sub build_feed ($items, $epoch = time) {
  my $site = 'https://positivitybriefing.com/';
  my $updated = DateTime->from_epoch(epoch => $epoch, time_zone => 'UTC');
  my $feed = XML::Feed->new('Atom') or die XML::Feed->errstr;
  $feed->id("${site}feed.atom");
  $feed->title('Positivity Briefing');
  $feed->description('Something useful. Something hopeful. One small thing you can do today.');
  $feed->language('en-GB');
  $feed->modified($updated);
  $feed->self_link("${site}feed.atom");
  $feed->link($site);
  $feed->author('Dave Cross');

  for my $index (0 .. $#$items) {
    my $item = $items->[$index];
    die "Briefing contains characters that XML cannot represent\n"
      if $item->{text} =~ /[^\x09\x0A\x0D\x20-\x{D7FF}\x{E000}-\x{FFFD}\x{10000}-\x{10FFFF}]/;
    my $number = $index + 1;
    my $identity = JSON::MaybeXS->new->utf8->canonical->encode([$index, $item]);
    my $entry = XML::Feed::Entry->new('Atom');
    $entry->id("${site}feed.atom#" . sha256_hex($identity));
    $entry->title(ucfirst($item->{type}));
    $entry->modified($updated);
    $entry->link("${site}#item-$number");
    # XML::Feed recognises inline XHTML; escape briefing text before passing it in.
    $entry->content(encode_entities($item->{text}, q{<>&"'}));
    $feed->add_entry($entry);
  }

  my $xml = $feed->as_xml;
  $xml = encode('UTF-8', $xml) if utf8::is_utf8($xml);
  return $xml;
}

1;
