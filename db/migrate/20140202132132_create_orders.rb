class CreateOrders < ActiveRecord::Migration
  def change
    create_table :orders do |t|

      t.string :extern_id
      t.string :extern_system
      t.string :order_type
      t.string :market_label
      t.decimal :quantity
      t.decimal :target_quantity_no_fees
      t.decimal :target_quantity_incl_fees
      t.decimal :price
      t.string :state, default: :created  # :closed, :canceled

      t.timestamps
    end
  end
end
