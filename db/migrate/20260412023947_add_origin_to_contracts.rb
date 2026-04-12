class AddOriginToContracts < ActiveRecord::Migration[6.1]
  def change
    add_column :contracts, :origin, :string
  end
end
