class CreateGlobalValues < ActiveRecord::Migration
  def change
    create_table :global_values do |t|
      t.string :key
      t.text :value

      t.timestamps
    end
  end
end
