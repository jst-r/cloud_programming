This is a cloud computing project I did for university. It is a minimal replica
of how I image a Vercel deployment looks behind the scenes.

# How to use

1. Clone the repo
2. Install [OpenTofu]() (a portable executable for Windows is included in the
   repo)
3. Provide your AWS credentials (I use the AWS CLI for that, but other options
   are available)
4. Run `tofu init`
5. Run `tofu plan`
6. Run `tofu apply`
7. Go to the URL printed in the output
