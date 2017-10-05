require 'spec_helper'
describe 'report2slack' do
  context 'with default values for all parameters' do
    it { should contain_class('report2slack') }
  end
end
