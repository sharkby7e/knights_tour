class AddNameColumnToTour < ActiveRecord::Migration[8.1]
  def change
    add_column :tours, :name, :string
  end
end
