class CreateSquares < ActiveRecord::Migration[8.1]
  def change
    create_table :squares do |t|
      t.integer :x
      t.integer :y
      t.boolean :has_knight, default: false
      t.boolean :has_been_visited, default: false

      t.timestamps
    end
  end
end
