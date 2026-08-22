# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_22_205035) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "moves", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position", null: false
    t.string "square", null: false
    t.bigint "tour_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tour_id", "position"], name: "index_moves_on_tour_id_and_position", unique: true
    t.index ["tour_id", "square"], name: "index_moves_on_tour_id_and_square", unique: true
    t.index ["tour_id"], name: "index_moves_on_tour_id"
  end

  create_table "tours", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "moves", "tours"
end
