require 'spec_helper'

describe PgBundle::Dsl do

  subject { PgBundle::Dsl.new.eval_pgfile(File.expand_path('../Pgfile', __FILE__)) }
  its(:database) { should be_a PgBundle::Database }
  its('database.port') { should be 54321 }
  its(:extensions) { should be_a Hash }
end
