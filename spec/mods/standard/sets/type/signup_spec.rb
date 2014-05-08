# -*- encoding : utf-8 -*-


describe Card::Set::Type::Signup do
  
  before do
    Card::Auth.current_id = Card::AnonymousID
  end
  
  
  context 'request form' do
    before do
      card = Card.new :type_id=>Card::SignupID
      @form = card.format.render_new
    end
    
    it 'should prompt to signup' do
      Card::Auth.as :anonymous do
        @form.match( /Sign up/ ).should be_true
      end
    end
  end
  

   
  context 'signup (without approval)' do
    before do
      ActionMailer::Base.deliveries = [] #needed?
      
      Card::Auth.as_bot do
        Card.create! :name=>'User+*type+*create', :content=>'[[Anyone]]'
        Card.create! :name=>'*request+*to', :content=>'request@wagn.org'
      end
      @request = Card.create! :name=>'Big Bad Wolf', :type_id=>Card::SignupID, '+*account'=>{ 
        '+*email'=>'wolf@wagn.org', '+*password'=>'wolf'
      }
      @account = @request.account
      @token = @account.token
    end
    
    it 'should create all the necessary cards' do
      @request.type_id.should == Card::SignupID
      @account.email.should == 'wolf@wagn.org'
      @account.status.should == 'pending'
      @account.salt.should_not == ''
      @account.password.length.should > 10 #encrypted
      @account.token.should be_present
    end
  
    it 'should send email with an appropriate link' do
    end
    
    it 'should create an authenticable token' do
      Card::Auth.authenticate_by_token(@token).should == @request.id
    end
    
    it 'should notify someone' do
      ActionMailer::Base.deliveries.last.to.should == ['request@wagn.org']
    end
    
    it 'should be activated by an update' do
      Card::Env.params[:token] = @token
      hash = {}
      @request.update_attributes hash
      #puts @request.errors.full_messages * "\n"
      @request.errors.should be_empty
      @request.type_id.should == Card::UserID
      @account.status_card.refresh.content.should == 'active'
      Card[ @account.name ].active?.should be_true
    end
  
  
  end


  context 'signup (with approval)' do

  end
  
  
 

end