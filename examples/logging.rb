require 'milter'

class MyMilter < Milter::Milter

  def connect( hostname, family, port, address )
    puts "connect from #{address}:#{port} (#{hostname})."
    return Response.continue
  end

  def helo( text )
    puts "helo #{text}"
    return Response.continue
  end

  def mail_from( mailfrom, esmtp_info )
    puts "mail_from: #{mailfrom}"
    return Response.continue
  end

  def rcpt_to( mailto, esmtp_info )
    puts "rcpt_to: #{mailto} (#{esmtp_info})"
    return Response.continue
  end

  def data
    puts "data"
    return Response.continue
  end

  def unknown( data )
    puts "unknown smtp command: #{data}"
    return Response.continue
  end

  def header( k, v )
    puts "header: #{k} => #{v}"
    @headers[k] = [] if @headers[k].nil?
    @headers[k] <<  v
    return Response.continue
  end

  def end_headers
    puts "end of headers; headers: #{@headers.inspect}"
    return Response.continue
  end

  def end_body( data )
    puts "end of body: #{data}; body: #{@body}"
    return Response.continue
  end

  def abort
    puts "abort"
    return Response.continue
  end

  def quit
    puts "quit"
    return Response.continue
  end

  def macro( cmd, data )
    puts "#{Milter::COMMANDS[cmd]} macros: #{data.inspect}"
    return Response.continue
  end

end

Milter.register(MyMilter)
Milter.start
