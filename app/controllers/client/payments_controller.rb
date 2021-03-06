class Client::PaymentsController < ApplicationController
    before_action :set_order

  def new
    @cleaner = @order.cleaning.user
    @cleanings = @cleaner.cleanings
    @cleaning = @order.cleaning
    @car = @cleaning.car
    @ratings = []
  end

  def create
    customer = Stripe::Customer.create(
      source: params[:stripeToken],
      email:  params[:stripeEmail]
    )

    charge = Stripe::Charge.create(
      customer:     customer.id,   # You should store this customer id and re-use it.
      amount:       @order.amount_cents, # or amount_pennies
      description:  "Payment for cleaning #{@order.cleaning.id} for order #{@order.id}",
      currency:     @order.amount.currency
    )

    @order.update(payment: charge.to_json, state: 'paid')
    @order.cleaning.update(status: "confirmed")
    broadcast_paid
    redirect_to client_order_path(@order)

  rescue Stripe::CardError => e
    flash[:alert] = e.message
    redirect_to new_client_order_payment_path(@order)
  end

private

  def set_order
    @order = Order.where(state: 'pending').find(params[:order_id])
  end

  def broadcast_paid
    ActionCable.server.broadcast("paid", {
      paid_partial: ApplicationController.renderer.render(
        partial: "shared/card_cleaning_for_cleaner_dashboard",
        locals: { missions: @order.cleaning.user.cleanings.where(status: "pending").or(@order.cleaning.user.cleanings.where(status: "accepted")).or(@order.cleaning.user.cleanings.where(status: "confirmed")).sort_by(&:status).reverse}
      ),
      current_user_id: @order.cleaning.user.id
    })
  end
end
