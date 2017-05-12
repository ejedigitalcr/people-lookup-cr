Aws.config.update({
  region: 'us-west-2',
  credentials: Aws::Credentials.new(
    Rails.application.secrets.aws[:access_key_id],
    Rails.application.secrets.aws[:secret_access_key]
  )
})
