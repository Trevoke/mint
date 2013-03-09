require 'csv'
require 'yaml'
require 'rails/all'
require 'active_record'
require 'active_support'
require 'sqlite3'

begin # define ActiveRecord objects
  class Transaction < ActiveRecord::Base
    has_one :transaction_type
    has_one :category
    has_one :account
  end

  class TransactionType < ActiveRecord::Base
  end
  class Category < ActiveRecord::Base
  end
  class Account < ActiveRecord::Base
  end

  ActiveRecord::Base.establish_connection(
    adapter: 'sqlite3',
    database: 'mint.db'
  )
end

def dateobj string
  Date.strptime(str, "%m/%d/%Y").strftime("%d-%m-%Y")
end

def create_database_from_csv
  FileUtils.rm_rf("mint.db")

  ActiveRecord::Migration.class_eval do
    create_table :transaction_types do |t|
      t.string :name
    end
    create_table :categories do |t|
      t.string :name
    end
    create_table :accounts do |t|
      t.string :name
    end
    create_table :transactions do |t|
      t.date :date
      t.string :description
      t.string :original_description
      t.integer :amount
      t.integer :transaction_type_id
      t.integer :category_id
      t.integer :account_id
      t.string :labels
      t.string :notes
    end
  end

  CSV.open('transactions.csv', headers: true) do |csv|
    csv.each do |t|
      x = t.to_hash
      x['Date'] = dateobj(x['Date'])
      x['Amount'] = x['Amount'].to_i
      Transaction.create! date: x['Date'],
        description: x['Description'],
        original_description: x['Original Description'],
        amount: x['Amount'],
        transaction_type_id: TransactionType.find_or_create_by_name(x['Transaction Type']).id,
        category_id: Category.find_or_create_by_name(x['Category']).id,
        account_id: Account.find_or_create_by_name(x['Account Name']).id,
        labels: x['Labels'],
        notes: x['Notes']
    end
  end
end

first_transaction = Transaction.order('date ASC').limit(1).first
last_transaction = Transaction.order('date DESC').limit(1).first
done_months = []
all_credit = []
all_debit = []
all_net = []

for_csving_purposes = []
(first_transaction.date..last_transaction.date).each do |date|
  flag = date.strftime("%Y-%m")
  next if done_months.include? flag

  b = date.beginning_of_month.to_s(:db)
  e = date.end_of_month.to_s(:db)
  t_this_month = Transaction.where "date >= ? and date <= ?", b, e
  money_in = TransactionType.find_by_name 'credit'
  money_out = TransactionType.find_by_name 'debit'

  credits = t_this_month.where "transaction_type_id = #{money_in.id}"# and account_id in (2, 10)"
  debits =  t_this_month.where "transaction_type_id = #{money_out.id}"# and account_id in (1, 15)"

  credits_sum = credits.map(&:amount).inject(&:+) || 0
  debits_sum = debits.map(&:amount).inject(&:+) || 0
  all_credit << credits_sum
  all_debit << debits_sum
  all_net << (credits_sum - debits_sum)

  for_csving_purposes << [flag, credits_sum, debits_sum, credits_sum - debits_sum]
  done_months << flag
end

all_credit.delete_if { |x| x.zero?}
all_debit.delete_if { |x| x.zero?}
all_credit.delete_if { |x| x == 49690 }
all_net.delete_if { |x| x > 40000 }

puts "Minimum credit: #{all_credit.min}"
puts "Maximum credit: #{all_credit.max}"
puts "Minimum debit: #{all_debit.min}"
puts "Maximum debit: #{all_debit.max}"
puts "Average credit: #{all_credit.inject(&:+) / all_credit.size.to_f}"
puts "Average debit: #{all_debit.inject(&:+) / all_debit.size.to_f}"
puts "Minimum net income: #{all_net.min}"
puts "Maximum net income: #{all_net.max}"
puts "Average net income: #{all_net.inject(&:+) / all_net.size.to_f}"

CSV.open('output.csv', 'wb') do |f|
  for_csving_purposes.each do |month|
    f << month
  end
end
