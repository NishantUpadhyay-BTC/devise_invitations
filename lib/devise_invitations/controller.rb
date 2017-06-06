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

      deal = Deal.find_by(loan_officer_profile_id: invitation.sent_by.profile.id, buyer_profile_id: user.profile.id, active: false, pending: true)
      deal.update(active: true, pending: false)
      UserMailer.delay.notify_loan_officer(invitation.sent_by, user)
      UserMailer.delay.welcome_notifier(user)
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
