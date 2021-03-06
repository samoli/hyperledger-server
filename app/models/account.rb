class Account < ActiveRecord::Base
  include Confirmable
  include Signable
  
  belongs_to :ledger
  
  validates_presence_of :ledger, :public_key
  validates :public_key, uniqueness: true, rsa_public_key: true
  
  before_create do |account|
    digest = Digest::MD5.new.digest(account.public_key)
    account.code = Digest.hexencode(digest)
    account.balance = 0
  end
  
private
  
  def broadcast_params
    {account: {ledger: ledger.name, public_key: public_key}}
  end
  
end
