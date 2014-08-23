class CreateComments < ActiveRecord::Migration
  def change
    create_table :comments do |t|
      t.belongs_to :user
      t.belongs_to :associated_transaction, class_name
      t.text :content

      t.timestamps
    end
  end
end
