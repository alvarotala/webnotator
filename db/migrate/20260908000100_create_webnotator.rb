class CreateWebnotator < ActiveRecord::Migration[8.1]
  def change
    create_table :admins do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.timestamps
    end
    add_index :admins, :email, unique: true
    create_table :projects do |t|
      t.string :name, null: false
      t.string :public_key, null: false
      t.string :invite_token, null: false
      t.jsonb :origins, null: false, default: []
      t.timestamps
    end
    add_index :projects, :public_key, unique: true
    add_index :projects, :invite_token, unique: true
    create_table :annotations do |t|
      t.references :project, null: false, foreign_key: true
      t.string :author_name, null: false
      t.string :kind, null: false, default: "change"
      t.string :status, null: false, default: "pending"
      t.text :body, null: false
      t.text :page_url, null: false
      t.string :page_title
      t.jsonb :element, null: false, default: {}
      t.jsonb :viewport, null: false, default: {}
      t.string :client_id, null: false
      t.string :screenshot_key
      t.string :screenshot_type
      t.timestamps
    end
    add_index :annotations, [:project_id, :client_id], unique: true
    add_index :annotations, [:project_id, :status, :created_at]
    add_check_constraint :annotations, "status IN ('pending','in_progress','resolved','discarded')", name: "annotation_status"
    add_check_constraint :annotations, "kind IN ('bug','change','suggestion')", name: "annotation_kind"
  end
end
