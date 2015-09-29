
format :html do

  def default_new_args args
    super args
    args.merge!(
      optional_help: :show, #, optional_menu: :never
      buttons: button_tag( 'Submit', disable_with: 'Submitting', situation: 'primary' ),
      account: card.fetch( trait: :account, new: {} ),
      title:   'Sign up',
      hidden:  {
        success: (card.rule(:thanks) || '_self'),
        'card[type_id]' => card.type_id
      }
    )

    if Auth.signed_in? and args[:account].confirm_ok?
      args[:title] = 'Invite'
      args[:buttons] = button_tag 'Send Invitation', situation: 'primary'
      args[:hidden][:success] = '_self'
    end
  end

  view :new do |args|
    #FIXME - make more use of standard new view?

    frame_and_form :create, args, 'main-success'=>"REDIRECT" do
      [
        _render_name_formgroup( help: 'usually first and last name' ),
        _optional_render( :account_formgroups, args),
        ( card.structure ? edit_slot : ''),
        _optional_render( :button_formgroup, args )
      ]
    end
  end


  view :account_formgroups do |args|
    sub_args = { structure: true }
    sub_args[:no_password] = true if Auth.signed_in?
    Auth.as_bot { subformat( args[:account] )._render :content_formgroup, sub_args }  #YUCK!!!!
  end


  view :core do |args|
    headings, links = [], []
    if !card.new_card? #necessary?
      by_anon = card.creator_id == AnonymousID
      headings << %(<strong>#{ card.name }</strong> #{ 'was' if !by_anon } signed up on #{ format_date card.created_at })
      if account = card.account
        token_action = 'Send'
        if account.token.present?
          headings << "A verification email has been sent #{ "to #{account.email}" if account.email_card.ok? :read }"
          token_action = 'Resend'
        end
        if account.confirm_ok?
          links << link_to( "#{token_action} verification email", card_path("update/~#{card.id}?approve_with_token=true"  ) )
          links << link_to( "Approve without verification", card_path("update/~#{card.id}?approve_without_token=true") )
        end
        if card.ok? :delete
          links << link_to( "Deny and delete", card_path("delete/~#{card.id}") )
        end
        headings << links * '' if links.any?
      else
        headings << "ERROR: signup card missing account"
      end
    end
    %{<div class="invite-links">
        #{ headings.map { |h| "<div>#{h}</div>"} * "\n" }
      </div>
      #{ process_content render_raw }
    }
  end
end

event :activate_by_token, before: :approve, on: :update, when: proc{ |c| c.has_token? } do
  result = account ? account.authenticate_by_token( @env_token ) : "no account associated with #{name}"
  case result
  when Integer
    abort :failure, 'no field manipulation mid-activation' if subcards.present?
    # necessary because the rest of the action is performed as Wagn Bot
    activate_account
    Auth.signin id
    Auth.as_bot
    Env.params[:success] = ''
  when :token_expired
    resend_activation_token
    abort :success
  else
    abort :failure, "signup activation error: #{result}" # bad token or account
  end
end

def has_token?
  @env_token = Env.params[:token]
end

event :activate_account do
  add_subfield :account
  subfield(:account).add_subfield :status, :content =>'active'
  self.type_id = Card.default_accounted_type_id
  account.send_welcome_email
end

event :approve_with_token, on: :update, before: :approve, when: proc {|c| Env.params[:approve_with_token] } do
  abort :failure, 'illegal approval' unless account.confirm_ok?
  account.reset_token
  account.send_account_verification_email
end

event :approve_without_token, on: :update, before: :approve, when: proc {|c| Env.params[:approve_without_token] } do
  abort :failure, 'illegal approval' unless account.confirm_ok?
  activate_account
end

event :resend_activation_token do
  account.reset_token
  account.send_account_verification_email
  Env.params[:success] = {
    id: '_self',
    view: 'message',
    message: "Sorry, this token has expired. Please check your email for a new password reset link."
  }
end

def signed_in_as_me_without_password?
  Auth.signed_in? && Auth.current_id==id && account.password.blank?
end

event :redirect_to_edit_password, on: :update, after: :store, when: proc {|c| c.signed_in_as_me_without_password? } do
  Env.params[:success] = account.edit_password_success_args
end

event :preprocess_account_subcards, before: :process_subcards, on: :create do
  email = remove_subfield("+#{Card[:account].name}+#{Card[:email].name}")
  password = remove_subfield("+#{Card[:account].name}+#{Card[:password].name}")
  account = add_subfield :account
  account.add_subfield( :email, :content => email) if email
  account.add_subfield( :password, :content => password) if password

end

event :act_as_current_for_extend_phase, before: :extend, on: :create do
  Auth.current_id = self.id
end

