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

ActiveRecord::Schema[8.0].define(version: 2026_06_11_200000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "buyers", force: :cascade do |t|
    t.string "name", null: false
    t.string "buyer_type", null: false
    t.string "backed_by"
    t.text "thesis"
    t.string "sectors", default: [], null: false, array: true
    t.bigint "min_revenue"
    t.bigint "max_revenue"
    t.integer "acquisitions_count", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.string "source"
    t.string "source_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["buyer_type"], name: "index_buyers_on_buyer_type"
    t.index ["sectors"], name: "index_buyers_on_sectors", using: :gin
  end

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

  create_table "deal_accesses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "deal_id", null: false
    t.string "status", default: "requested", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deal_id"], name: "index_deal_accesses_on_deal_id"
    t.index ["user_id", "deal_id"], name: "index_deal_accesses_on_user_id_and_deal_id", unique: true
    t.index ["user_id"], name: "index_deal_accesses_on_user_id"
  end

  create_table "deals", force: :cascade do |t|
    t.string "reference", null: false
    t.string "title", null: false
    t.string "industry", null: false
    t.bigint "revenue"
    t.bigint "ebitda"
    t.bigint "asking_price"
    t.string "location"
    t.text "teaser"
    t.string "highlights", default: [], null: false, array: true
    t.boolean "recurring", default: false, null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "codename"
    t.index ["industry"], name: "index_deals_on_industry"
    t.index ["reference"], name: "index_deals_on_reference", unique: true
    t.index ["status"], name: "index_deals_on_status"
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
    t.bigint "user_id"
    t.index ["user_id"], name: "index_leads_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
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
    t.bigint "user_id"
    t.index ["lead_id"], name: "index_tool_runs_on_lead_id"
    t.index ["status"], name: "index_tool_runs_on_status"
    t.index ["tool_type"], name: "index_tool_runs_on_tool_type"
    t.index ["user_id"], name: "index_tool_runs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.string "name"
    t.string "role", default: "seller", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "mandate_industries", default: [], null: false, array: true
    t.bigint "mandate_min_revenue"
    t.bigint "mandate_max_revenue"
    t.string "mandate_location"
    t.string "buyer_type"
    t.string "phone"
    t.string "occupation"
    t.text "bio"
    t.string "experience_level"
    t.string "funding_sources", default: [], null: false, array: true
    t.string "personal_liquidity"
    t.bigint "ev_min"
    t.bigint "ev_max"
    t.bigint "ebitda_min"
    t.bigint "ebitda_max"
    t.string "geographic_focus", default: [], null: false, array: true
    t.text "additional_context"
    t.string "approval_status", default: "incomplete", null: false
    t.string "provider"
    t.string "uid"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
  end

  add_foreign_key "deal_accesses", "deals"
  add_foreign_key "deal_accesses", "users"
  add_foreign_key "leads", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "tool_runs", "leads"
  add_foreign_key "tool_runs", "users"
end
