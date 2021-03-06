require 'test_helper'

class LedgersControllerTest < ActionController::TestCase
  
  setup do
    ledger_key = OpenSSL::PKey::RSA.new 2048
    account_key = OpenSSL::PKey::RSA.new 2048
    @node_key = OpenSSL::PKey::RSA.new 2048
    
    @public_key = ledger_key.public_key.to_pem
    @ledger_data = { public_key: @public_key, name: 'Moonbucks', url: 'moonbucks.com' }
    @account_data = { public_key: account_key.public_key.to_pem }
    
    @node = ConsensusNode.create!(url: 'localtest-2', public_key: @node_key.public_key.to_pem)
    
    stub_request(:post, /.*/)
    request.accept = 'application/json'
  end
  
  test "valid POST should be successful" do
    post :create, ledger: @ledger_data, primary_account: @account_data
    assert_equal '201', response.code
  end
  
  test "POST with a bad public key should be unsuccessful" do
    post :create, ledger: { public_key: '123', name: 'Moonbucks', url: 'moonbucks.com' }, primary_account: @account_data
    assert_equal '422', response.code
  end
  
  test "POST without primary account data should be unsuccessful" do
    post :create, ledger: @ledger_data
    assert_equal '422', response.code
  end
  
  test "duplicate POST should not be successful" do
    create_ledger
    post :create, ledger: @ledger_data, primary_account: @account_data
    refute_equal '201', response.code
  end
  
  test "valid POST should broadcast identical prepare message" do
    post :create, ledger: @ledger_data, primary_account: @account_data
    assert_requested(:post, 'localtest-2/ledgers/prepare',
                     body: hash_including({ledger: @ledger_data, primary_account: @account_data}))
  end
  
  # Prepare messages
  test "valid POST with signature should create resource" do
    assert_difference 'Ledger.count', 1 do
      post :prepare, valid_prepare_post
    end
  end
  
  test "valid POST which creates a resource should broadcast to the other nodes" do
    post :prepare, valid_prepare_post
    assert_requested(:post, 'localtest-2/ledgers/prepare')
  end
  
  test "valid POST which confirms an existing resource should not re-broadcast" do
    create_ledger
    post :prepare, valid_prepare_post
    assert_requested(:post, 'localtest-2/ledgers/prepare', times: 1)
  end
  
  # Prepare records
  test "valid POST should sign prepare record for self and primary account" do
    assert_difference 'PrepareConfirmation.signed.count', 2 do
      post :create, ledger: @ledger_data, primary_account: @account_data
    end
  end
  
  test "valid POST which confirms an existing resource should sign a prepare record" do
    ledger = create_ledger
    assert_difference 'ledger.prepare_confirmations.signed.count', 1 do
      post :prepare, valid_prepare_post
    end
  end
  
  test "POST with invalid signature should not sign a prepare record" do
    ledger = create_ledger
    assert_no_difference 'ledger.prepare_confirmations.signed.count' do
      post :prepare, ledger: @ledger_data,
                     primary_account: @account_data,
                     authentication: { node: 'test', signature: '123' }
    end
  end
  
  # Commit records
  test "POST with commit should sign a commit record" do
    ledger = create_ledger
    assert_difference 'ledger.commit_confirmations.signed.count', 1 do
      post :commit, valid_commit_post
    end
  end
  
private
  
  def valid_prepare_post
    data = { ledger: @ledger_data, primary_account: @account_data }
    data.merge({ authentication: { node: 'localtest-2', signature: sign(@node_key, data) } })
  end
  
  def valid_commit_post
    data = { ledger: @ledger_data, primary_account: @account_data, commit: true }
    data.merge({ authentication: { node: 'localtest-2', signature: sign(@node_key, data) } })
  end
  
  def create_ledger
    ledger = Ledger.new(@ledger_data)
    ledger.primary_account = ledger.accounts.build(@account_data)
    ledger.save!
    ledger
  end
end
