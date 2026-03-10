output "bucket_frames" {
  value = aws_s3_bucket.frames.id
}

output "bucket_exports" {
  value = aws_s3_bucket.exports.id
}

output "bucket_models" {
  value = aws_s3_bucket.models.id
}

output "bucket_hard_examples" {
  value = aws_s3_bucket.hard_examples.id
}

output "bucket_backups" {
  value = aws_s3_bucket.backups.id
}

output "bucket_frames_arn" {
  value = aws_s3_bucket.frames.arn
}

output "bucket_exports_arn" {
  value = aws_s3_bucket.exports.arn
}

output "bucket_models_arn" {
  value = aws_s3_bucket.models.arn
}

output "bucket_hard_examples_arn" {
  value = aws_s3_bucket.hard_examples.arn
}

output "bucket_backups_arn" {
  value = aws_s3_bucket.backups.arn
}
