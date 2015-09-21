require 'spec_helper'

describe PgBundle::Dsl do
  subject { PgBundle::Dsl.new.eval_pgfile(File.expand_path('../Pgfile', __FILE__)).first }

  its(:database) { should be_a PgBundle::Database }
  its('database.host') { should eq 'localhost' }
  its(:extensions) { should be_a Hash }

  context 'parsing options' do
    let(:opts) { { :github => 'adjust/numhstore', :branch => 'topic' } }

    specify { subject.extensions['myext'].source.branch.should eq 'topic' }
  end
end
