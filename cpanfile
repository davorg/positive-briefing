requires 'perl', '5.036';

requires 'OpenAPI::Client::OpenAI';
requires 'JSON::MaybeXS';
requires 'JSON::Validator';
requires 'Path::Tiny', '0.119';

on 'test' => sub {
  requires 'Test::More';
};
