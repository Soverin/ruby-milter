require 'milter/version'
require 'eventmachine'

module Milter
  SMFI_PROT_VERSION = 6  # "MTA - libmilter protocol version"
  MILTER_LEN_BYTES  = 4  # "length of 32 bit integer in bytes"

  # Milter binary protocol commands
  SMFIC_ABORT   = 'A' # "Abort"
  SMFIC_BODY    = 'B' # "Body chunk"
  SMFIC_CONNECT = 'C' # "Connection information"
  SMFIC_MACRO   = 'D' # "Define macro"
  SMFIC_BODYEOB = 'E' # "final body chunk (End)"
  SMFIC_HELO    = 'H' # "HELO/EHLO"
  SMFIC_QUIT_NC = 'K' # "QUIT but new connection follows"
  SMFIC_HEADER  = 'L' # "Header"
  SMFIC_MAIL    = 'M' # "MAIL from"
  SMFIC_EOH     = 'N' # "EOH"
  SMFIC_OPTNEG  = 'O' # "Option negotation"
  SMFIC_QUIT    = 'Q' # "QUIT"
  SMFIC_RCPT    = 'R' # "RCPT to"
  SMFIC_DATA    = 'T' # "DATA"
  SMFIC_UNKNOWN = 'U' # "Any unknown command"

  # mappings for Ruby callbacks
  COMMANDS = {
    SMFIC_ABORT   => :abort,
    SMFIC_BODY    => :body,
    SMFIC_CONNECT => :connect,
    SMFIC_MACRO   => :macro,
    SMFIC_BODYEOB => :end_body,
    SMFIC_HELO    => :helo,
    SMFIC_QUIT_NC => :quit_new_connection,
    SMFIC_HEADER  => :header,
    SMFIC_MAIL    => :mail_from,
    SMFIC_EOH     => :end_headers,
    SMFIC_OPTNEG  => :opt_neg,
    SMFIC_QUIT    => :quit,
    SMFIC_RCPT    => :rcpt_to,
    SMFIC_DATA    => :data,
    SMFIC_UNKNOWN => :unknown,
  }

  # actions(replies)
  RESPONSE = {
    :addrcpt     => '+', # SMFIR_ADDRCPT     # "add recipient"
    :delrcpt     => '-', # SMFIR_DELRCPT     # "remove recipient"
    :addrcpt_par => '2', # SMFIR_ADDRCPT_PAR # "add recipient (incl. ESMTP args)"
    :shutdown    => '4', # SMFIR_SHUTDOWN    # "421: shutdown (internal to MTA)"
    :accept      => 'a', # SMFIR_ACCEPT      # "accept"
    :replbody    => 'b', # SMFIR_REPLBODY    # "replace body (chunk)"
    :continue    => 'c', # SMFIR_CONTINUE    # "continue"
    :discard     => 'd', # SMFIR_DISCARD     # "discard"
    :chgfrom     => 'e', # SMFIR_CHGFROM     # "change envelope sender (from)"
    :connfail    => 'f', # SMFIR_CONN_FAIL   # "cause a connection failure"
    :addheader   => 'h', # SMFIR_ADDHEADER   # "add header"
    :insheader   => 'i', # SMFIR_INSHEADER   # "insert header"
    :setsymlist  => 'l', # SMFIR_SETSYMLIST  # "set list of symbols (macros)"
    :chgheader   => 'm', # SMFIR_CHGHEADER   # "change header"
    :progress    => 'p', # SMFIR_PROGRESS    # "progress"
    :quarantine  => 'q', # SMFIR_QUARANTINE  # "quarantine"
    :reject      => 'r', # SMFIR_REJECT      # "reject"
    :skip        => 's', # SMFIR_SKIP        # "skip"
    :tempfail    => 't', # SMFIR_TEMPFAIL    # "tempfail"
    :replycode   => 'y', # SMFIR_REPLYCODE   # "reply code etc"
  }

  # What the MTA can send/filter wants in protocol
  PROTOCOL_FLAGS = {
    :noconnect   => 0x000001, # SMFIP_NOCONNECT   # MTA should not send connect info
    :nohelo      => 0x000002, # SMFIP_NOHELO      # MTA should not send HELO info
    :nomail      => 0x000004, # SMFIP_NOMAIL      # MTA should not send MAIL info
    :norcpt      => 0x000008, # SMFIP_NORCPT      # MTA should not send RCPT info
    :nobody      => 0x000010, # SMFIP_NOBODY      # MTA should not send body
    :nohdrs      => 0x000020, # SMFIP_NOHDRS      # MTA should not send headers
    :noeoh       => 0x000040, # SMFIP_NOEOH       # MTA should not send EOH
    :nohrepl     => 0x000080, # SMFIP_NR_HDR      # No reply for headers
    :nounknown   => 0x000100, # SMFIP_NOUNKNOWN   # MTA should not send unknown commands
    :nodata      => 0x000200, # SMFIP_NODATA      # MTA should not send DATA
    :skip        => 0x000400, # SMFIP_SKIP        # MTA understands SMFIS_SKIP
    :rcpt_rej    => 0x000800, # SMFIP_RCPT_REJ    # MTA should also send rejected RCPTs
    :nr_conn     => 0x001000, # SMFIP_NR_CONN     # No reply for connect
    :nr_helo     => 0x002000, # SMFIP_NR_HELO     # No reply for HELO
    :nr_mail     => 0x004000, # SMFIP_NR_MAIL     # No reply for MAIL
    :nr_rcpt     => 0x008000, # SMFIP_NR_RCPT     # No reply for RCPT
    :nr_data     => 0x010000, # SMFIP_NR_DATA     # No reply for DATA
    :nr_unkn     => 0x020000, # SMFIP_NR_UNKN     # No reply for UNKN
    :nr_eoh      => 0x040000, # SMFIP_NR_EOH      # No reply for eoh
    :nr_body     => 0x080000, # SMFIP_NR_BODY     # No reply for body chunk
    :hrd_leadspc => 0x100000, # SMFIP_HDR_LEADSPC # header value leading space
  }

  # What the filter might do -- values to be ORed together
  # (from mfapi.h)
  ACTION_FLAGS = {
    :none        => 0x000, # SMFIF_NONE        # no flags
    :addhdrs     => 0x001, # SMFIF_ADDHDRS     # filter may add headers
    :chgbody     => 0x002, # SMFIF_CHGBODY     # filter may replace body
    :addrcpt     => 0x004, # SMFIF_ADDRCPT     # filter may add recipients
    :delrcpt     => 0x008, # SMFIF_DELRCPT     # filter may delete recipients
    :chghdrs     => 0x010, # SMFIF_CHGHDRS     # filter may change/delete headers
    :quarantine  => 0x020, # SMFIF_QUARANTINE  # filter may quarantine envelope
    :chgfrom     => 0x040, # SMFIF_CHGFROM     # filter may change "from" (envelope sender)
    :addrcpt_par => 0x080, # SMFIF_ADDRCPT_PAR # add recipients incl. args
    :setsymlist  => 0x100, # SMFIF_SETSYMLIST  # filter can send set of symbols (macros) that it wants
    :set_curr    => 0x1FF, # SMFI_CURR_ACTS    # Set of all actions in the current milter version
  }

  class Milter
    def initialize
      @body = ''
      @headers = {}
      @recipients = []
    end

    def opt_neg( ver, actions, protocol )
      puts "New Milter connection - version: %s, action flags: %x, protocol flags: %x." % [ver, actions, protocol]
      _actions  = ACTION_FLAGS[:set_curr]    # allow all supported actions
      # _actions  = ACTION_FLAGS.values_at(:addhrds, :chgfrom).reduce(:+)  # example for enabling individual actions
      _protocol = PROTOCOL_FLAGS.values_at(:rcpt_rej).reduce(:+)  # register callback for rejected recipients
      return SMFIC_OPTNEG + [ SMFI_PROT_VERSION, _actions, _protocol].pack("NNN")
    end

    def rcpt_to( mailto, esmtp_info )
      @recipients << mailto
      return Response.continue
    end

    def header( k,v )
      @headers[k] = [] if @headers[k].nil?
      @headers[k] <<  v
      return Response.continue
    end

    def body( data )
      @body << data
      return Response.continue
    end

    class Response
      class << self
        def continue
          RESPONSE[:continue]
        end

        def reject
          RESPONSE[:reject]
        end

        def accept
          RESPONSE[:accept]
        end

        #email must be enclosed in <>
        def delete_rcpt( email )
          RESPONSE[:delrcpt] + email + "\0"
        end

        #email must be enclosed in <>
        def add_rcpt( email )
          RESPONSE[:addrcpt] + email + "\0"
        end

        #index is for multiple occurences of same header (starts at 1)
        def change_header( header, value, index=1 )
          index = [index].pack('N')
          RESPONSE[:chgheader] + "#{index}#{header}\0#{value}" + "\0"
        end

        def replace_body( body )
          RESPONSE[:replbody] + body + "\0"
        end
      end
    end
  end

  class MilterConnectionHandler < EM::Connection
    @@milter_class = Milter

    def initialize
      @data = ''
      @milter = @@milter_class.new
    end

    def send_milter_response( res )
      r = [ res.size ].pack('N') + res
      send_data(r)
    end

    # SMFIC_OPTNEG, two integers
    def parse_opt_neg( data )
      ver, actions, protocol = data.unpack('NNN')
      return [ver, actions, protocol]
    end

    # SMFIC_MACRO, \0 separated list of args, NULL-terminated
    def parse_macro( data )
      cmd, macros = data[0].chr, data[1..-1].split("\0" )
      return [cmd, Hash[*macros]]
    end

    # SMFIC_CONNECT, two args (strings)
    def parse_connect( data )
      hostname, val = data.split("\0", 2)
      family = val[0].unpack('C')
      port = val[1...3].unpack('n')
      address = val[3..-1]
      return [hostname, family, port, address]
    end

    # SMFIC_HELO, one arg (string)
    def parse_helo( data )
      return [data]
    end

    # SMFIC_MAIL, \0 separated list of args, NULL-terminated
    def parse_mail_from( data )
      mailfrom, esmtp_info = data.split("\0", 2 )
      return [mailfrom, esmtp_info.split("\0")]
    end

    # SMFIC_RCPT, \0 separated list of args, NULL-terminated
    def parse_rcpt_to( data )
      mailto, esmtp_info = data.split("\0", 2 )
      return [mailto, esmtp_info.split("\0")]
    end

    # SMFIC_HEADER, two args (strings)
    def parse_header( data )
      k,v = data.split("\0", 2)
      return [k, v.delete("\0")]
    end

    # SMFIC_EOH, no args
    def parse_end_headers( data )
      return []
    end

    # SMFIC_BODY, one arg (string)
    def parse_body( data )
      return [ data.delete("\0") ]
    end

    # SMFIC_BODYEOB, one arg (string)
    def parse_end_body( data )
      return [data]
    end

    # SMFIC_QUIT, no args
    def prase_quit( data )
      return []
    end

    # SMFIC_ABORT, no args
    def parse_abort( data )
      return []
    end

    # SMFIC_DATA, no args
    def parse_data( data )
      return []
    end

    # SMFIC_UNKNOWN, one arg (string)
    def parse_unknown( data )
      return data
    end

    # SMFIC_QUIT_NC, no args
    def parse_quit_new_connection( data )
      return []
    end

    def receive_data( data )
      # puts "Data: #{data.bytes.map(&:chr)}"
      @data << data
      while @data.size >= MILTER_LEN_BYTES
        pkt_len = @data[0...MILTER_LEN_BYTES].unpack('N').first
        if @data.size >= MILTER_LEN_BYTES + pkt_len
          @data.slice!(0, MILTER_LEN_BYTES)
          pkt = @data.slice!(0, pkt_len)
          cmd, val = pkt[0].chr, pkt[1..-1]

          if COMMANDS.include?(cmd) and @milter.respond_to?(COMMANDS[cmd])
            method_name = COMMANDS[cmd]
            args = []
            args = self.send('parse_' + method_name.to_s, val ) if self.respond_to?('parse_' + method_name.to_s )
            ret = @milter.send(method_name, *args )

            close_connection and return if cmd == SMFIC_QUIT
            next if cmd == SMFIC_MACRO

            if not ret.is_a? Array
              ret = [ ret ]
            end

            ret.each do |r|
              send_milter_response(r)
            end
          else
            next if cmd == SMFIC_MACRO
            send_milter_response(RESPONSE[:continue])
          end
        else
          break
        end
      end
    end

    class << self
      def register( milter_class )
        @@milter_class = milter_class
      end
    end
  end

  class << self
    def register( milter_class )
      MilterConnectionHandler.register(milter_class)
    end

    def start( host = 'localhost', port = 8888 )
      EM.run do
        Signal.trap("INT")  { EventMachine.stop }
        Signal.trap("TERM") { EventMachine.stop }
        EM.start_server host, port, MilterConnectionHandler
        puts "Server started on #{host}:#{port}."
      end
    end
  end
end
