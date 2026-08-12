class CreateMoves < ActiveRecord::Migration[8.1]
  def change
    create_table :moves do |t|
      t.references :tour, null: false, foreign_key: true
      t.string :square, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :moves, [ :tour_id, :position ], unique: true
    add_index :moves, [ :tour_id, :square ], unique: true
  end
end
