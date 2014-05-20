require 'spec_helper'
describe PgBundle::Definition do
  subject do
    d = PgBundle::Definition.new
    d.server = PgBundle::Extension.new('localhost')
    d.database = database
    d.extensions['bar'] = PgBundle::Extension.new('bar', path: './spec/sample_extensions//bar', requires: 'ltree')
    d.extensions['baz'] = PgBundle::Extension.new('baz', path: './spec/sample_extensions/baz', requires: 'foo')
    d.extensions['foo'] = PgBundle::Extension.new('foo', '0.0.2', path: './spec/sample_extensions/foo')
    d
  end

  it 'missing_extensions' do
    subject.missing_extensions.map(&:name).should eq %w(bar baz foo)
  end

  it 'should install missing extension' do
    subject.install.map(&:name).should eq %w(bar baz foo)
  end
end
