require File.expand_path(File.dirname(__FILE__) + "/../prmilter")

# example
# change mail body
class MyMilter < PRMilter::Milter
  def header( k,v )
    puts "#{k} => #{v}"
    return Response.continue
  end

  def end_body( *args )
    puts "BODY => #{@body}"
    return [Response.replace_body("hogehoge"), Response.continue]
  end
end

PRMilter.register(MyMilter)
PRMilter.start
