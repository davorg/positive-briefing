requires 'perl', '5.036';

requires 'OpenAPI::Client::OpenAI';
requires 'JSON::MaybeXS';
requires 'JSON::Validator';
requires 'Path::Tiny', '0.119';
requires 'XML::Feed';
requires 'DateTime';
requires 'HTML::Entities';

on 'test' => sub {
  requires 'Test::More';
  requires 'XML::LibXML';
};
