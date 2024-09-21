#!/bin/sh
set -e

#
# Script for updating this project's RubyGems to the latest versions by running `bundle install`
# and committing and pushing the regenerated Gemfile.lock files to GitHub.
#
# Usage: update-rubygems.sh
#
# Author: John Topley (john.topley@ons.gov.uk)
#
echo "Regenerating agent-parent-image/Gemfile.lock..."
cd ./agent-parent-image
rm Gemfile.lock
bundle install

git add Gemfile.lock
git commit -m "Updated dependencies"
git push

echo "Regenerating webapp-parent-image/Gemfile.lock..."
cd ./webapp-parent-image
rm Gemfile.lock
bundle install

git add Gemfile.lock
git commit -m "Updated dependencies"
git push

echo "Waiting 5 minutes for Cloud Build pipeline to build agent-parent-image and webapp-parent-image..."
sleep 300

cd ./agent
rm Gemfile.lock
bundle install

echo "Regenerating agent/Gemfile.lock..."
git add Gemfile.lock
git commit -m "Updated dependencies"
git push

cd ./webapp
rm Gemfile.lock
bundle install

echo "Regenerating webapp/Gemfile.lock..."
git add Gemfile.lock
git commit -m "Updated dependencies"
git push

echo "Finished!"
