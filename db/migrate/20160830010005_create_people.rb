class CreatePeople < ActiveRecord::Migration[5.0]
  def up
    migration = Aws::Record::TableMigration.new(Person)
    begin
      migration.create!(
        provisioned_throughput: {
          read_capacity_units: 5,
          write_capacity_units: 2
        }
      )
      migration.wait_until_available
    rescue Aws::DynamoDB::Errors::ResourceInUseException
      # Table exists, ignore
    end
  end

  def down
    migration = Aws::Record::TableMigration.new(Person)
    migration.delete!
  end
end
