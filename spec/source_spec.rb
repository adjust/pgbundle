require 'spec_helper'

describe PgBundle::PathSource do
  subject { PgBundle::PathSource.new('./foo/bar') }
  its(:path) { should eq './foo/bar' }
end

describe PgBundle::GithubSource do
  let(:git) { "git clone git@github.com:foo/bar.git -b #{branch} --quiet --depth=1" }

  subject { PgBundle::GithubSource.new('foo/bar', opts) }

  context 'default options' do
    let(:branch) { 'master' }
    let(:opts)   { {} }

    its(:git_command) { should match git }
  end

  context 'custom options' do
    let(:branch) { 'topic' }
    let(:opts)   { { :branch => 'topic' } }

    its(:git_command) { should match git }
  end
end
