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

ActiveRecord::Schema[8.0].define(version: 2026_06_11_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "comps", force: :cascade do |t|
    t.string "industry", null: false
    t.string "name", null: false
    t.text "description"
    t.bigint "revenue"
    t.bigint "earnings"
    t.bigint "sale_price"
    t.decimal "revenue_multiple", precision: 6, scale: 2
    t.decimal "earnings_multiple", precision: 6, scale: 2
    t.boolean "recurring", default: false, null: false
    t.string "kind", default: "benchmark", null: false
    t.string "period"
    t.string "source"
    t.string "source_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["industry", "name"], name: "index_comps_on_industry_and_name", unique: true
    t.index ["industry"], name: "index_comps_on_industry"
  end

  create_table "leads", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "phone"
    t.string "company_name"
    t.string "company_website"
    t.string "company_type"
    t.string "revenue_range"
    t.string "ebitda_range"
    t.string "source"
    t.text "message"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tool_runs", force: :cascade do |t|
    t.string "tool_type", null: false
    t.string "website"
    t.string "company_name"
    t.jsonb "inputs", default: {}, null: false
    t.jsonb "analysis", default: {}, null: false
    t.jsonb "result", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.text "error"
    t.bigint "lead_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lead_id"], name: "index_tool_runs_on_lead_id"
    t.index ["status"], name: "index_tool_runs_on_status"
    t.index ["tool_type"], name: "index_tool_runs_on_tool_type"
  end

  add_foreign_key "tool_runs", "leads"
end
