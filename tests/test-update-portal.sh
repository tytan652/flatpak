#!/bin/bash
#
# Copyright (C) 2019 Colin Walters <walters@verbum.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

set -euo pipefail

. $(dirname $0)/libtest.sh

skip_without_bwrap

echo "1..4"

setup_repo
install_repo

run_with_sandboxed_bus ${test_builddir}/test-update-portal monitor monitor.pid > update-monitor.out
MONITOR_PID=$(cat monitor.pid)

OLD_COMMIT=$(cat repos/test/refs/heads/app/org.test.Hello/$ARCH/master)
make_updated_app
NEW_COMMIT=$(cat repos/test/refs/heads/app/org.test.Hello/$ARCH/master)

for i in {15..1}; do
    if grep -q -e "update_available .* remote=${NEW_COMMIT}" update-monitor.out; then
        assert_file_has_content update-monitor.out "running=${OLD_COMMIT} local=${OLD_COMMIT} remote=${NEW_COMMIT}"
        echo found update ${NEW_COMMIT}
        break
    fi
    if [ $i == 1 ]; then
        assert_not_reached "Timed out when looking for update 1"
    fi
    sleep 1
done

make_updated_app test "" master UPDATE2

NEWER_COMMIT=$(cat repos/test/refs/heads/app/org.test.Hello/$ARCH/master)

for i in {15..1}; do
    if grep -q -e "update_available .* remote=${NEWER_COMMIT}"  update-monitor.out; then
        assert_file_has_content update-monitor.out "running=${OLD_COMMIT} local=${OLD_COMMIT} remote=${NEWER_COMMIT}"
        echo found update ${NEWER_COMMIT}
        break
    fi
    if [ $i == 1 ]; then
        assert_not_reached "Timed out when looking for update 2"
    fi
    sleep 1
done

# Make sure monitor is dead
kill -9 $MONITOR_PID

echo "ok monitor updates"

run_with_sandboxed_bus ${test_builddir}/test-update-portal update monitor.pid
MONITOR_PID=$(cat monitor.pid)

echo "ok update self"

run_with_sandboxed_bus ${test_builddir}/test-update-portal update-null monitor.pid
MONITOR_PID=$(cat monitor.pid)

echo "ok null-update self"

make_updated_app test "" master UPDATE3

# Break the repo so that the update fails
cp -r repos/test/objects repos/test/orig-objects
find repos/test/objects -name "*.filez" | xargs  -I FILENAME mv FILENAME FILENAME.broken

run_with_sandboxed_bus ${test_builddir}/test-update-portal update-fail monitor.pid
MONITOR_PID=$(cat monitor.pid)

# Unbreak it again
rm -rf repos/test/objects
mv repos/test/orig-objects repos/test/objects


echo "ok update fail"