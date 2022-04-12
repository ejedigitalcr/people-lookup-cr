require 'rails_helper'

RSpec.describe Person, type: :model do
  it "is valid with all the data" do
    expect(build(:person)).to be_valid
  end

  it { is_expected.to validate_presence_of(:id) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:last_name_1) }
  it { is_expected.to validate_presence_of(:last_name_2) }
  it { is_expected.to validate_inclusion_of(:gender).in_array([1, 2]) }
end
