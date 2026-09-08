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

ActiveRecord::Schema[8.1].define(version: 2026_09_08_000100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "admins", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
  end

  create_table "annotations", force: :cascade do |t|
    t.string "author_name", null: false
    t.text "body", null: false
    t.string "client_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "element", default: {}, null: false
    t.string "kind", default: "change", null: false
    t.string "page_title"
    t.text "page_url", null: false
    t.bigint "project_id", null: false
    t.string "screenshot_key"
    t.string "screenshot_type"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.jsonb "viewport", default: {}, null: false
    t.index ["project_id", "client_id"], name: "index_annotations_on_project_id_and_client_id", unique: true
    t.index ["project_id", "status", "created_at"], name: "index_annotations_on_project_id_and_status_and_created_at"
    t.index ["project_id"], name: "index_annotations_on_project_id"
    t.check_constraint "kind::text = ANY (ARRAY['bug'::character varying, 'change'::character varying, 'suggestion'::character varying]::text[])", name: "annotation_kind"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'in_progress'::character varying, 'resolved'::character varying, 'discarded'::character varying]::text[])", name: "annotation_status"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "invite_token", null: false
    t.string "name", null: false
    t.jsonb "origins", default: [], null: false
    t.string "public_key", null: false
    t.datetime "updated_at", null: false
    t.index ["invite_token"], name: "index_projects_on_invite_token", unique: true
    t.index ["public_key"], name: "index_projects_on_public_key", unique: true
  end

  add_foreign_key "annotations", "projects"
end
