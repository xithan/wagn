# -*- encoding : utf-8 -*-
require 'open-uri'


class Card
  class Mailer < ActionMailer::Base
    
    @@defaults = Wagn.config.email_defaults || {}
    @@defaults.symbolize_keys!
    @@defaults[:return_path] ||= @@defaults[:from] if @@defaults[:from]
    @@defaults[:charset] ||= 'utf-8'
    default @@defaults

    include Wagn::Location
    
    class << self
      def layout message
        %{
          <!DOCTYPE html>
          <html>
            <head>
            <style>
            .diff-red {
              text-decoration: line-through;
              color: #ff5050;
            }
            .diff-green {
                color: #41ad41;
            }
            </style>
            </head>
            <body>
              #{message}
            </body>
          </html>
        }
      end
    end
  end
end
