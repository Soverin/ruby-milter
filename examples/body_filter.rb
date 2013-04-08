require 'milter'

# example
# change mail body
class MyMilter < Milter::Milter
  def header( k,v )
    puts "#{k} => #{v}"
    return Response.continue
  end

  def end_body( *args )
    puts "BODY => #{@body}"
    return [Response.replace_body("hogehoge"), Response.continue]
  end
end

Milter.register(MyMilter)
Milter.start
