class ContactsController < ApplicationController
  before_filter :ensure_signed_in_without_redirect, only: [:index, :create, :show, :create]
  before_filter :ensure_coinbase_account_linked, only: [:import]
  before_filter :check_for_unlinked_coinbase_account, only: [:index, :show, :create]

  include ActionView::Helpers::TextHelper

  LOAD_CONTACTS_PAGE_LIMIT = 500

  def index
    @contacts = current_user.contacts.order('name ASC')

    render layout: false
  end

  def import
    contacts = []

    1.upto(Float::INFINITY) do |p|
      cb_response = current_coinbase_client.transactions(p, limit: LOAD_CONTACTS_PAGE_LIMIT)
      transactions = cb_response['transactions'].map { |t| t['transaction'] }
      coinbase_id = cb_response['current_user']['id']

      break if transactions.empty?

      transactions.each do |t|
        target = t['recipient'] if t['sender'] && t['sender']['id'] == coinbase_id
        target = t['sender'] if t['recipient'] && t['recipient']['id'] == coinbase_id

        next if target.nil?

        name = target['name']
        email = target['email']
        user = CoinbaseAccount.user_with_email(email)

        contacts << {
          address: email,
          name: user ? user.name : name
        }
      end

      break if transactions.count < LOAD_CONTACTS_PAGE_LIMIT
    end

    count = 0

    contacts.uniq! { |c| c[:address] }
    contacts.each do |c|
      next if current_user.contacts.find_by(address: c[:address].to_s)
      current_user.contacts.create!(c)
      count += 1
    end

    redirect_to dashboard_url, flash: {success: "#{pluralize(count, 'contact')} have been imported from Coinbase transaction history. "}
  end

  def new
    render layout: false
  end

  def create
  end

  def show
    render layout: false
  end
end
