module Card                         
  class PermissionDenied < Wagn::PermissionDenied
    attr_reader :card
    def initialize(card)
      @card = card
      super build_message 
    end    
    
    def build_message
      "for #{@card.name}, #{@card.errors.on(:permission_denied)}"
    end
  end
  
  module Permissions
    # Permissions --------------------------------------------------------------
    
    module ClassMethods 
      def ok?(operation)
        new.ok? operation
      end
      def ok!(operation)
        new.ok! operation
      end
    end

    # ok? and ok! are public facing methods to approve one operation at a time
    def ok?(operation) 
      self.operation_approved = true
      send("approve_#{operation}")     
      operation_approved
    end  
    
    def ok!(operation)
      if !ok?(operation)
        raise PermissionDenied.new(self)
      end
      true
    end
    
    def destroy_with_permissions
      ok! :delete
      # FIXME this is not tested and the error will be confusing
      dependents.each do |dep| dep.ok! :delete end
      destroy_without_permissions
    end
    
    def destroy_with_permissions!
      ok! :delete
      dependents.each do |dep| dep.ok! :delete end
      destroy_without_permissions!
    end

    def save_with_permissions(perform_checking=true)
      if perform_checking && approved? || !perform_checking
        save_without_permissions(perform_checking)
      else
        # Decided I want to raise errors more..
        raise PermissionDenied.new(self)
        #false
      end
    end 
    
    def save_with_permissions!
      if approved?
        save_without_permissions!
      else
        raise PermissionDenied.new(self)
      end
    end
    
    def permissions_with_reader=(perms)
      permissions_without_reader = perms
      reader = perms.find{|x|x.task=='reader'}
    end

    def approved?  
      self.operation_approved = true
      if new_record?
        approve_create 
      end
      updates.each_pair do |attr,value|
        send("approve_#{attr}")
      end
      operation_approved
    end
    
    def permit(task, party) #assign permissions
      ok! :permissions unless new_record?# might need stronger checks on new records 
      perms = self.permissions.reject { |p| p.task == task.to_s }
      perms << Permission.new(:task=>task.to_s, :party=>party)
      self.permissions= perms
    end
    
     
    def who_can(operation)
      permissions.each do |perm| 
        return perm.party if perm.task == operation.to_s
      end
      return nil
    end 
    
    def personal_user
      return nil if simple?
#      warn "personal user tag: #{tag.extension}  #{tag.extension.class == ::User}"
      return tag.extension if tag.extension.class == ::User 
      return trunk.personal_user 
    end
    
    protected
    def deny_because(why)    
      [why].flatten.each do |err|
        errors.add :permission_denied, err
      end
      self.operation_approved = false
    end
     
=begin  we may yet need this...
    def require_permission(operation)
      unless System.ok? operation
        deny_because "you don't have '#{operation}' permission"
      end
    end
=end

    def lets_user(operation)
      return true if System.always_ok?
      System.party_ok? who_can(operation)
    end

    def approve_create
      unless cardtype.lets_user :create
        deny_because "Sorry, you don't have permission to create #{cardtype.name} cards"
      end
    end
    
    def approve_read
      approve_task(:read)
    end
    
    def approve_edit
      approve_task(:edit)
    end
    
    def approve_comment
      return false unless who_can(:comment)
      approve_task(:comment, 'comment on')
    end
    
    def approve_delete
      approve_task(:delete)
    end
    
    def approve_task(operation, verb=nil) #read, edit, comment, delete
      verb ||= operation.to_s
      unless self.lets_user operation
        deny_because "Sorry, you don't have permission to #{verb} this card"
      end
    end

    def approve_name 
      approve_edit unless new_record?
    end

    def approve_type
      unless new_record?       
        approve_edit 
        approve_delete
      end
      new_self = clone_to_type( type ) # note: would rather do this through ok? api...
      new_self.send(:approve_create) 
      if err = new_self.errors.on(:permission_denied) 
        deny_because err
      end
    end

    def approve_content
      # FIXME - deny changes to hard templated cards?
      #if templatee?
      #  deny_because "templated cards can't be edited directly"
      #end
      approve_edit unless new_record?
    end

=begin 
    def approve_personal_card
      pu = personal_user
      cu = ::User.current_user
      if !pu
        deny_because 'Only cards plussed to user cards can be personal'
      end
      if pu.login == 'anon'
        deny_because "Only signed in users can have their own personal cards"
      end 
    end
=end

    def approve_permissions
      return if System.always_ok?
      unless System.ok? :set_card_permissions or 
          (System.ok?(:set_personal_card_permissions) and (personal_user == ::User.current_user)) or 
          new_record? then #FIXME-perm.  on new cards we should check that permission has not been altered from default unless user can set permissions.
          
        deny_because "Sorry, you're not currently allowed to set permissions" 
      end
    end
    
    def self.included(base)   
      super
      base.extend(ClassMethods)
      base.class_eval do  
        attr_accessor :operation_approved 
        alias_method_chain :destroy, :permissions  
        alias_method_chain :destroy!, :permissions  
        alias_method_chain :save, :permissions
        alias_method_chain :save!, :permissions
        #alias_method_chain :permissions=, :reader
      end
      
    end
    
  end
end
