require 'spec_helper'

describe PgBundle::PathSource do
  subject { PgBundle::PathSource.new('./foo/bar') }
  its(:path) { should eq './foo/bar' }
end

describe PgBundle::GithubSource do
  let(:git) { "git clone git@github.com:foo/bar.git -b #{branch} --quiet --depth=1" }

  context 'default options' do
    let(:branch) { 'master' }

    subject { PgBundle::GithubSource.new('foo/bar') }

    its(:git_command) { should match git }
  end

  context 'custom options' do
    let(:branch) { 'topic' }

    subject { PgBundle::GithubSource.new('foo/bar', 'topic') }

    its(:git_command) { should match git }
  end
end
