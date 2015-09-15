require 'spec_helper'
require 'notifier'

describe Array do
  describe '#to_sentence' do
    subject { array.to_sentence }

    context 'with 0 items' do
      let(:array) { [] }

      it { should eql '' }
    end

    context 'with 1 item' do
      let(:array) { [1] }

      it { should eql '1' }
    end

    context 'with 2 items' do
      let(:array) { [1, 2] }

      it { should eql '1 and 2' }
    end

    context 'with 3 items' do
      let(:array) { [1, 2, 3] }

      it { should eql '1, 2, and 3' }
    end
  end
end
