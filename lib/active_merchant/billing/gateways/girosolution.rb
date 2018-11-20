require 'openssl'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    #
    # = Girosolution Gateway
    #
    # == Usage
    #
    #  require 'active_merchant'
    #
    #  # get a payment gateway object, amount in cents
    #  gateway = ActiveMerchant::Billing::GirosolutionGateway.new(
    #    merchant_id:     "5103056",
    #    project_id:      "45490",
    #    secret:          "vh293izPP7De",
    #    merchant_tx_id:  "4711",
    #    amount:          "100",
    #    currency:        "EUR",
    #    purpose:         "Ihr Alvito Einkauf 4711"
    #  )
    #
    #  # start the transaction
    #  response = gateway.start(
    #    type:            "AUTH",
    #    locale:          "de",
    #    mobile:          "1",
    #    pkn:             "create",
    #    recurring:       "0",
    #    url_redirect:    "https://alvito.com/de/checkout/after-payment/",
    #    url_notify:      "https://alvito.com/de/checkout/payment-update/"
    #  )
    #
    #  puts response.success?       # Check whether the request was successful
    #  puts response.message        # Retrieve the message returned by API
    #  puts response.authorization  # Retrieve the transaktions-ID returned by API
    #  puts response.redirect       # Retrieve the redirect url
    #
    #  transaction_id = response.authorization
    #
    #  # capture transaction
    #  response = gateway.capture(transaction_id)
    # 
    #  # refund transaction
    #  response = gateway.refund(transaction_id)
    #
    #  # cancel transaction
    #  response = gateway.void(transaction_id)
    #
    class GirosolutionGateway < Gateway
      self.test_url = 'https://payment.girosolution.de/girocheckout/api/v2/transaction/'
      self.live_url = 'https://payment.girosolution.de/girocheckout/api/v2/transaction/'

      self.supported_countries = ['DE']
      self.default_currency = 'EUR'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master]

      self.homepage_url = 'https://www.girosolution.de'
      self.display_name = 'girosolution.de'

      def initialize(options={})
        requires!(options,
          :merchant_id,
          :project_id,
          :secret,
          :merchant_tx_id,
          :amount,
          :currency,
          :purpose
        )
        super
      end

      def start(options={})
        requires!(options,
          :type,
          :locale,
          :mobile,
          :pkn,
          :recurring,
          :url_redirect,
          :url_notify
        )
        post = {}
        o = @options.merge(options)
        add_base_options(post, o)
        add_start_options(post, o)
        add_hmac_hash(post, o)
        commit('start', post)
      end

      def capture(reference)
        post = {}
        o = merge_reference(reference)
        add_base_options(post, o)
        add_reference(post, o)
        add_hmac_hash(post, o)
        commit('capture', post)
      end

      def refund(reference)
        post = {}
        o = merge_reference(reference)
        add_base_options(post, o)
        add_reference(post, o)
        add_hmac_hash(post, o)
        commit('refund', post)
      end

      def void(reference)
        post = {}
        o = merge_reference(reference)
        add_void_options(post, o)
        add_hmac_hash(post, o)
        commit('void', post)
      end

      # # TODO: implement
      # def payment(money, payment, options={})
      #   post = {}
      # 
      #   commit('payment', post)
      # end

      private

      def merge_reference(reference)
        @options.merge(
          {:reference => reference}
        )
      end

      def add_base_options(post, options)
        add_pair post, 'merchantId',   options[:merchant_id].to_s
        add_pair post, 'projectId',    options[:project_id].to_s
        add_pair post, 'merchantTxId', options[:merchant_tx_id].to_s
        add_pair post, 'amount',       options[:amount].to_s
        add_pair post, 'currency',     options[:currency].to_s
      end

      def add_start_options(post, options)
        add_pair post, 'purpose',      options[:purpose].to_s
        add_pair post, 'type',         options[:type].to_s
        add_pair post, 'locale',       options[:locale].to_s
        add_pair post, 'mobile',       options[:mobile].to_s
        add_pair post, 'pkn',          options[:pkn].to_s
        add_pair post, 'recurring',    options[:recurring].to_s
        add_pair post, 'urlRedirect',  options[:url_redirect].to_s
        add_pair post, 'urlNotify',    options[:url_notify].to_s
      end

      def add_void_options(post, options)
        add_pair post, 'merchantId',   options[:merchant_id].to_s
        add_pair post, 'projectId',    options[:project_id].to_s
        add_pair post, 'merchantTxId', options[:merchant_tx_id].to_s
        add_pair post, 'reference',    options[:reference].to_s
      end

      def add_reference(post, options)
        add_pair post, 'reference',    options[:reference].to_s
      end

      def add_hmac_hash(post, options)
        add_pair post, 'hash',         hmac_md5_hash(post,options[:secret].to_s)
      end

      def add_pair(post, key, value)
        post[key] = value if value.present?
      end

      def hmac_md5_hash(post,secret)
        s = String.new.tap do |output|
          post.keys.each { |key| output << post[key] }
        end
        OpenSSL::HMAC.hexdigest("MD5", secret, s)
      end

      def parse(body)
        JSON.parse body
      end

      def commit(action, parameters)
        url = live_url
        response = parse(ssl_post(url+action, post_data(parameters)))

        GirosolutionResponse.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?
        )
      end

      def success_from(response)
        response["rc"].to_i == 0
      end

      def message_from(response)
        response["message"]
      end

      def authorization_from(response)
        response["reference"]
      end

      def post_data(parameters = {})
        parameters.to_query
      end
    end
    
    class GirosolutionResponse < Response
      def redirect
        @params['redirect']
      end
    end
    
  end
end
