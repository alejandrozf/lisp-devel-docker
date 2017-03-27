#!/bin/bash

# The entry point to the Lisp Development image. Is responsible for creating a
# new user (lisp) with the requested UID. Upon creating the user, privileges are
# immediately changed to those of the lisp user. Its behavior is controlled
# through one environment variable:
#
# LISP_DEVEL_UID: Defaults to 0. This is the UID and GID of the lisp user.

if grep -qF /home/lisp /etc/passwd
then
    echo "Already created" > /dev/null
else
    _UID="${LISP_DEVEL_UID:-0}"

    groupadd -g "${_UID}" -o lisp

    useradd --shell /bin/bash -u "${_UID}" -g "${_UID}" \
            -o -c "Autogenerated lisp devel user." lisp

    # If the UID is different than 0, we must change the owner of
    # everything in /home/lisp to UID. However, we'd like to not touch
    # anything that's been mounted into the container. Presumably, the
    # user is requesting a specific UID because of some constraints
    # with sharing volumes, so we assume that mounted volumes have the
    # owners that the user really desires.
    if [ "${_UID}" != 0 ]; then
        MOUNTED_DIR_FILE=$(mktemp)
        HOME_FOLDER_FILES_FILE=$(mktemp)
        TEMP_FILE=$(mktemp)
        find /home/lisp -print0 > ${HOME_FOLDER_FILES_FILE}
        cut -d " " -f2 /proc/mounts | grep ^/home/lisp/ > ${MOUNTED_DIR_FILE}

        while read -r line; do
            grep -P -v -z ^\\Q"$(printf %b $(echo $line | sed -r 's/(\\[0-7]{3})([0-7])/\1\\06\2/g') | sed -r 's/\\E/\\\\EE\\Q/g' | perl -p -e 's/\n/\\E\\n\\Q/' )"\\E ${HOME_FOLDER_FILES_FILE} > ${TEMP_FILE}
            cp ${TEMP_FILE} ${HOME_FOLDER_FILES_FILE}
        done < ${MOUNTED_DIR_FILE}

        cat "${HOME_FOLDER_FILES_FILE}" | xargs -0 chown lisp:lisp

        rm "${MOUNTED_DIR_FILE}"
        rm "${HOME_FOLDER_FILES_FILE}"
        rm "${TEMP_FILE}"
    fi


    TEMP_PASSWD=$(mktemp)
    tail -n 1 /etc/passwd > ${TEMP_PASSWD}
    head -n -1 /etc/passwd >> ${TEMP_PASSWD}
    cp /etc/passwd /etc/passwd-
    chmod 644 ${TEMP_PASSWD}
    mv ${TEMP_PASSWD} /etc/passwd

fi
export HOME="/home/lisp"

exec /usr/local/bin/gosu lisp "$@"
