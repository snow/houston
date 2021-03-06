require 'uri'
require 'socket'
require 'openssl'
require 'forwardable'

module Houston
  class Connection
    extend Forwardable
    def_delegators :@ssl, :read, :write
    def_delegators :@uri, :scheme, :host, :port

    attr_reader :ssl, :socket, :certificate, :passphrase

    class << self
      def open(uri, certificate, passphrase)
        return unless block_given?

        connection = new(uri, certificate, passphrase)
        connection.open

        yield connection

        connection.close
      end
    end

    def initialize(uri, certificate, passphrase)
      @uri = URI(uri)
      @certificate = certificate
      @passphrase = passphrase
    end

    def open(options = {})
      return false if open?

      # @socket = TCPSocket.new(@uri.host, @uri.port)
      @socket = Socket.tcp(@uri.host, @uri.port,
                           connect_timeout: options[:timeout])

      context = OpenSSL::SSL::SSLContext.new
      context.key = OpenSSL::PKey::RSA.new(@certificate, @passphrase)
      context.cert = OpenSSL::X509::Certificate.new(@certificate)

      @ssl = OpenSSL::SSL::SSLSocket.new(@socket, context)
      @ssl.sync = true
      @ssl.connect
    end

    def open?
      not (@ssl and @socket).nil?
    end

    def close
      return false if closed?

      @ssl.close
      @ssl = nil

      @socket.close
      @socket = nil
    end

    def closed?
      not open?
    end
  end
end
