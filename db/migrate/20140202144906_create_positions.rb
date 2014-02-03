class CreatePositions < ActiveRecord::Migration
  def change
    create_table :positions do |t|
      t.integer :input_order_id
      t.integer :output_order_id
      t.string :state, default: :created #created = waiting for input order to be processed, active - watching for sell or cancel, closed, canceled
      t.string :position_type

      t.timestamps
    end
  end
end
