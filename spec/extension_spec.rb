require 'spec_helper'
describe PgBundle::Extension  do
  describe 'Basiscs'  do
    subject { PgBundle::Extension.new('foo', '1.2.3', github: 'bar/foo', requires: 'baz') }

    its(:name) { should eq 'foo' }
    its(:version) { should eq '1.2.3' }
    its('dependencies.first.last') { should be_a PgBundle::Extension }
    its(:source) { should be_a PgBundle::GithubSource }
  end

  describe 'Installation' do

    context 'version available' do
      subject { PgBundle::Extension.new('foo', '0.0.2', path: './spec/sample_extensions/foo') }

      it 'should not be available before install' do
        subject.available?(database).should be false
      end

      it 'should be available after install' do
        subject.install(database)
        subject.available?(database).should be true
      end

      context 'wrong version installed' do
        subject { PgBundle::Extension.new('foo', '0.0.2', path: './spec/sample_extensions/foo') }
        let(:wrong_version) { PgBundle::Extension.new('foo', '0.0.1', path: './spec/sample_extensions/foo') }
        before do
          wrong_version.install(database)
          database.connection.exec "CREATE EXTENSION foo VERSION '0.0.2'"
        end

        it 'should be already installed' do
          subject.should be_created_any_version(database)
        end

        it 'should be available' do
          subject.should be_available(database)
        end
      end

      context 'with require' do
        let(:dependend) { PgBundle::Extension.new('bar', path: './spec/sample_extensions/bar', requires: 'ltree') }
        subject { PgBundle::Extension.new('foo', '0.0.2', path: './spec/sample_extensions/foo', requires: dependend) }

        it 'requires should be installable' do
          dependend.should_not be_available(database)
          subject.install(database).should be true
          dependend.should be_available(database)
        end

      end
    end

    context 'version not available' do
      subject { PgBundle::Extension.new('foo', '0.0.3', path: './spec/sample_extensions/foo') }

      it 'should raise ExtensionNotFound' do
        expect { subject.install(database) }.to raise_error PgBundle::ExtensionNotFound, 'specified Version 0.0.3 for Extension foo not available'
      end

      it 'should not be available although it is installed' do
        subject.available?(database).should be false
      end
    end

    context 'require not found'  do
      subject { PgBundle::Extension.new('foo', '0.0.2', path: './spec/sample_extensions/foo', requires: PgBundle::Extension.new('noope')) }

      it 'should raise DependencyNotFound' do
        expect { subject.install(database) }.to raise_error PgBundle::DependencyNotFound, "Can't install Dependency for Extension foo: Source for Extension noope not found"
      end
    end
  end
end
