require "spec_helper"

describe Stellar::Client do

  subject(:client) { Stellar::Client.default_testnet }

  describe "#create_account" do
    let(:source) { Stellar::Account.from_seed(CONFIG[:source_seed]) }
    let(:destination) { Stellar::Account.random }

    it "creates the account", vcr: {record: :once, match_requests_on: [:method]} do
      client.create_account(
        funder: source,
        account: destination,
        starting_balance: 100,
      )

      destination_info = client.account_info(destination)
      balances = destination_info.balances
      expect(balances).to_not be_empty
      native_asset_balance_info = balances.find do |b|
        b["asset_type"] == "native"
      end
      expect(native_asset_balance_info["balance"].to_f).to eq 100.0
    end
  end

  describe "#account_info" do
    let(:account) { Stellar::Account.from_seed(CONFIG[:source_seed]) }
    let(:client) { Stellar::Client.default_testnet }

    it "returns the current details for the account", vcr: { record: :once, match_requests_on: [:method]} do
      response = client.account_info(account)

      expect(response.id).to eq "GCQSESW66AX4ZRZB7QWCIXSPX2BD7KLOYSS33IUGDCLO4XCPURZEEC6R"
      expect(response.paging_token).to be_empty
      expect(response.sequence).to eq "346973227974715"
      expect(response.subentry_count).to eq 0
      expect(response.thresholds).to include("low_threshold" => 0, "med_threshold" => 0, "high_threshold" => 0)
      expect(response.flags).to include("auth_required" => false, "auth_revocable" => false)
      expect(response.balances).to include("balance" => "3494.9997500", "asset_type" => "native")
      expect(response.signers).to include(
        "public_key" => "GCQSESW66AX4ZRZB7QWCIXSPX2BD7KLOYSS33IUGDCLO4XCPURZEEC6R",
        "weight" => 1,
        "type" => "ed25519_public_key",
        "key"=>"GCQSESW66AX4ZRZB7QWCIXSPX2BD7KLOYSS33IUGDCLO4XCPURZEEC6R"
      )
      expect(response.data).to be_empty
    end
  end

  describe "#send_payment" do
    let(:source) { Stellar::Account.from_seed(CONFIG[:source_seed]) }

    context "native asset" do
      let(:destination) { Stellar::Account.random }

      it "sends a native payment to the account", vcr: {record: :once, match_requests_on: [:method]} do
        client.create_account(
          funder: source,
          account: destination,
          starting_balance: 100,
        )

        amount = Stellar::Amount.new(150)

        client.send_payment(
          from: source,
          to: destination,
          amount: amount,
        )

        destination_info = client.account_info(destination)
        balances = destination_info.balances
        expect(balances).to_not be_empty
        native_asset_balance_info = balances.find do |b|
          b["asset_type"] == "native"
        end
        expect(native_asset_balance_info["balance"].to_f).to eq 250.0
      end
    end

    context "alphanum4 asset" do
      let(:destination) { Stellar::Account.from_seed(CONFIG[:destination_seed]) }

      it "sends a alphanum4 asset to the destination", vcr: {record: :once, match_requests_on: [:method]} do
        destination_info = client.account_info(destination)
        old_balances = destination_info.balances
        old_btc_balance = old_balances.find do |b|
          b["asset_code"] == "BTC"
        end["balance"].to_f

        asset = Stellar::Asset.alphanum4("BTC", source.keypair)
        amount = Stellar::Amount.new(150, asset)

        client.send_payment(
          from: source,
          to: destination,
          amount: amount,
        )

        destination_info = client.account_info(destination)
        new_balances = destination_info.balances
        new_btc_balance = new_balances.find do |b|
          b["asset_code"] == "BTC"
        end["balance"].to_f

        expect(new_btc_balance - old_btc_balance).to eq 150.0
      end
    end

    context "alphanum12 asset" do
      let(:destination) { Stellar::Account.from_seed(CONFIG[:destination_seed]) }

      it "sends a alphanum12 asset to the destination", vcr: {record: :once, match_requests_on: [:method]} do
        destination_info = client.account_info(destination)
        old_balances = destination_info.balances
        old_btc_balance = old_balances.find do |b|
          b["asset_code"] == "LONGNAME"
        end["balance"].to_f

        asset = Stellar::Asset.alphanum12("LONGNAME", source.keypair)
        amount = Stellar::Amount.new(150, asset)

        client.send_payment(
          from: source,
          to: destination,
          amount: amount,
        )

        destination_info = client.account_info(destination)
        new_balances = destination_info.balances
        new_btc_balance = new_balances.find do |b|
          b["asset_code"] == "LONGNAME"
        end["balance"].to_f

        expect(new_btc_balance - old_btc_balance).to eq 150.0
      end
    end
  end

end
