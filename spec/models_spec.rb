require 'spec_helper'
require 'models'

describe Models::Unparseable do
  subject { described_class.new }

  it { should respond_to :data }
end
