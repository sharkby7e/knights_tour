class DropSquares < ActiveRecord::Migration[8.1]
  def up
    drop_table :squares
  end

  def down
    create_table :squares do |t|
      t.integer :x
      t.integer :y
      t.boolean :has_knight, default: false
      t.boolean :has_been_visited, default: false
      t.timestamps
    end
  end
end
