use v5.36;
use utf8;
use Path::Tiny qw(path);
use lib path(__FILE__)->realpath->parent(2)->child('lib')->stringify;
use PositivityBriefing::Feed qw(build_feed);
use Test::More;
use XML::LibXML;
use XML::LibXML::XPathContext;

my $items = [
  { type => 'useful', text => 'Try a café & a book: 2 < 3, “yes”! 🌅' },
  { type => 'hopeful', text => 'People can learn together.' },
  { type => 'action', text => '<script>alert("hello")</script>' },
];

sub parse_feed ($xml) {
  my $doc = XML::LibXML->load_xml(string => $xml, no_network => 1);
  my $xpath = XML::LibXML::XPathContext->new($doc);
  $xpath->registerNs(a => 'http://www.w3.org/2005/Atom');
  $xpath->registerNs(xhtml => 'http://www.w3.org/1999/xhtml');
  return $xpath;
}

my $xml = build_feed($items, 0);
my $feed = parse_feed($xml);
is($feed->findvalue('/a:feed/a:title'), 'Positivity Briefing', 'feed uses the new site title');
is($feed->findvalue('/a:feed/a:id'), 'https://positivitybriefing.com/feed.atom', 'feed has a permanent absolute ID');
is($feed->findvalue('/a:feed/a:link[@rel="self"]/@href'), 'https://positivitybriefing.com/feed.atom', 'self link uses the live domain');
is($feed->findvalue('/a:feed/a:link[@rel="alternate"]/@href'), 'https://positivitybriefing.com/', 'feed links to the site');
is($feed->findvalue('/a:feed/a:author/a:name'), 'Dave Cross', 'feed declares an author');
is($feed->findvalue('/a:feed/a:updated'), '1970-01-01T00:00:00Z', 'feed timestamp is in UTC');
my @entries = $feed->findnodes('/a:feed/a:entry');
is(scalar @entries, 3, 'feed contains all three entries');
for my $index (0 .. $#entries) {
  my $entry = $entries[$index];
  is($feed->findvalue('a:title', $entry), ucfirst($items->[$index]{type}), 'entry has a category title');
  is($feed->findvalue('a:content/xhtml:div', $entry), $items->[$index]{text}, 'entry preserves Unicode and XML metacharacters');
  is($feed->findvalue('a:content/@type', $entry), 'xhtml', 'content uses escaped inline XHTML');
  is($feed->findvalue('a:updated', $entry), '1970-01-01T00:00:00Z', 'entry has an update timestamp');
  is($feed->findvalue('a:link/@href', $entry), 'https://positivitybriefing.com/#item-' . ($index + 1), 'entry links to its item on the page');
}
is($feed->findvalue('count(//*[local-name()="script"])'), 0, 'markup in text is never interpreted as XML');
my @ids = map { $_->textContent } $feed->findnodes('/a:feed/a:entry/a:id');
my $later = parse_feed(build_feed($items, 86400));
is_deeply([map { $_->textContent } $later->findnodes('/a:feed/a:entry/a:id')], \@ids,
  'unchanged items retain IDs across regenerations');
$items->[0]{text} = 'A new idea.';
my $changed = parse_feed(build_feed($items, 86400));
my @changed_ids = map { $_->textContent } $changed->findnodes('/a:feed/a:entry/a:id');
isnt($changed_ids[0], $ids[0], 'new content receives a new entry ID');
is_deeply([@changed_ids[1, 2]], [@ids[1, 2]], 'other entry IDs remain stable');
my $duplicate = { type => 'useful', text => 'A repeated idea.' };
my $duplicates = parse_feed(build_feed([$duplicate, $duplicate, $duplicate], 0));
my %ids = map { $_->textContent => 1 } $duplicates->findnodes('/a:feed/a:entry/a:id');
is(scalar keys %ids, 3, 'even identical items have distinct entry IDs');

done_testing;
