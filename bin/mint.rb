require 'csv'
require 'yaml'
require 'rails/all'
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
  Date.strptime(string, "%m/%d/%Y").strftime("%d-%m-%Y")
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

#create_database_from_csv

first_transaction = Transaction.order('date ASC').limit(1).first
last_transaction = Transaction.order('date DESC').limit(1).first

done_months = []
all_credit = []
all_debit = []
all_net = []

for_csving_purposes = []

def money_earned_in_month month_transactions_arel
  @credit ||=  TransactionType.find_by_name 'credit'
  month_transactions_arel.where "transaction_type_id = #{@credit.id}"
end

def money_spent_in_month month_transactions_arel
  @debit ||=  TransactionType.find_by_name 'debit'
  month_transactions_arel.where "transaction_type_id = #{@debit.id}"
end

(first_transaction.date..last_transaction.date).each do |date|
  year_and_month = date.strftime("%Y-%m")
  next if done_months.include? year_and_month

  start_o_month = date.beginning_of_month.to_s(:db)
  end_o_month = date.end_of_month.to_s(:db)
  transactions = Transaction.where "date >= ? and date <= ?", start_o_month, end_o_month

  credits = money_earned_in_month transactions
  debits =  money_spent_in_month transactions

  paying_off_credit_card_debt = debits.where("description like '%transfer to CREDIT%'").map(&:amount).inject(&:+) || 0
  credits_sum = credits.map(&:amount).inject(&:+) || 0
  debits_sum = debits.map(&:amount).inject(&:+) || 0
  all_credit << credits_sum
  all_debit << debits_sum
  all_net << (credits_sum - debits_sum)

  for_csving_purposes << [year_and_month, credits_sum, paying_off_credit_card_debt, debits_sum, credits_sum - debits_sum]
  done_months << year_and_month
end

all_credit.delete_if { |x| x.zero?}
all_debit.delete_if { |x| x.zero?}

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
