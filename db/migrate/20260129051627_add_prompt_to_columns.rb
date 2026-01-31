class AddPromptToColumns < ActiveRecord::Migration[6.1]
  def change
    add_column :columns, :prompt, :text
  end
end
