class DeviseInvitations::InvitationsController < Devise::InvitationsController
  def accept
    invitation = DeviseInvitations::Invitation.pending.find_by(token: params[:token])

    if invitation.present? && invitation.valid?
      user = User.invite!(
        invitation_params(invitation).merge(
          skip_invitation: true
        ),
        invitation.sent_by
      )
      user.update(invitation_sent_at: Time.now.utc,
        profile_id: invitation.profile_id,
        profile_type: invitation.profile_type
      )
      user.role = Role.find_by_name(User::BUYER)
      statuses = DeviseInvitations::Invitation.statuses
      invitation.update(status: statuses[:accepted])
      DeviseInvitations::Invitation.pending
        .where(email: invitation.email)
        .update_all(status: statuses[:ignored])
      Deal.create(loan_officer_id: invitation.sent_by.id, buyer_id: user.id, active: true, invitation_sent: false, pending: false)
      UserMailer.notify_loan_officer(invitation.sent_by, user).deliver
      UserMailer.welcome_notifier(user).deliver
      redirect_to accept_invitation_url(user, invitation_token: user.raw_invitation_token)
    else
      flash[:error] = "Invalid invitation. Please try again later."
      redirect_to root_path
    end
  end

  private

  def invitation_params(invitation)
    { email: invitation.email }
  end
end
