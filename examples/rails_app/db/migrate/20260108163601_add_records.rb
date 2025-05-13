class AddRecords < ActiveRecord::Migration[8.1]
  def change
    create_table(:users) do |t|
      t.string(:name, null: false)
      t.string(:city)

      t.timestamps
    end

    create_table(:addresses) do |t|
      t.string(:city, null: false)
      t.belongs_to(:user, null: true)

      t.timestamps
    end

    create_table(:phone_numbers) do |t|
      t.string(:value)
      t.belongs_to(:user)
      t.timestamps
    end
  end
end
