require 'spec_helper'
describe PgBundle::PathSource do
  subject { PgBundle::PathSource.new('./foo/bar') }
  its(:path) { should eq './foo/bar' }
end

describe PgBundle::GithubSource do
  subject { PgBundle::GithubSource.new('foo/bar') }
  its(:path) { should eq 'foo/bar' }
end
