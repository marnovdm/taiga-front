###
# Copyright (C) 2014-2015 Taiga Agile LLC <taiga@taiga.io>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# File: attchments.controller.coffee
###

class AttachmentsController
    @.$inject = [
        "tgAttachmentsService"
    ]

    constructor: (@attachmentsService) ->

    addAttachment: (file) ->
        attachment = Immutable.fromJS({
            file: file,
            name: file.name,
            size: file.size
        })

        if @attachmentsService.validate(file)
            @.attachments = @.attachments.push(attachment)

            @.onAdd({attachment: attachment}) if @.onAdd

    addAttachments: (files) ->
        _.forEach files, @.addAttachment.bind(this)

    deleteAttachment: (toDeleteAttachment) ->
        @.attachments = @.attachments.filter (attachment) -> attachment != toDeleteAttachment

        @.onDelete({attachment: toDeleteAttachment}) if @.onDelete

angular.module("taigaComponents").controller("Attachments", AttachmentsController)


class AttachmentsController2
    @.$inject = [
        "tgAttachmentsService",
        "$rootScope",
        "$translate",
        "$tgConfirm"
    ]

    constructor: (@attachmentsService, @rootScope, @translate, @confirm) ->
        @.deprecatedsVisible = false
        @.uploadingAttachments = []

    loadAttachments: ->
        @attachmentsService.list(@.type, @.objId, @.projectId).then (files) =>
            @.attachments = files.map (file) ->
                attachment = Immutable.Map()

                return attachment.merge({
                    loading: false,
                    editable: false,
                    file: file
                })

    generate: () ->
        @.deprecatedsCount = @.attachments.count (it) -> it.get('is_deprecated')

    toggleDeprecatedsVisible: () ->
        @.deprecatedsVisible = !@.deprecatedsVisible
        @.generate()

    addAttachment: (file) ->
        if @attachmentsService.validate(file)
            @.uploadingAttachments.push(file)

            promise = @attachmentsService.upload(file, @.objId, @.projectId, @.type)

            promise.then (file) =>
                @.uploadingAttachments = @.uploadingAttachments.filter (uploading) ->
                    return uploading.name != file.get('name')

                attachment = Immutable.Map()

                attachment = attachment.merge({
                    file: file,
                    editable: true,
                    loading: false
                })

                @.attachments = @.attachments.push(attachment)

                @rootScope.$broadcast("attachment:create")

    addAttachments: (files) ->
        _.forEach files, @.addAttachment.bind(this)

    deleteAttachment: (toDeleteAttachment) ->
        title = @translate.instant("ATTACHMENT.TITLE_LIGHTBOX_DELETE_ATTACHMENT")
        message = @translate.instant("ATTACHMENT.MSG_LIGHTBOX_DELETE_ATTACHMENT", {
            fileName: toDeleteAttachment.getIn(['file', 'name'])
        })

        return @confirm.askOnDelete(title, message)
            .then (askResponse) =>
                onError = () =>
                    message = @translate.instant("ATTACHMENT.ERROR_DELETE_ATTACHMENT", {errorMessage: message})
                    @confirm.notify("error", null, message)

                    askResponse.finish(false)

                onSuccess = () =>
                    @.attachments = @.attachments.filter (attachment) -> attachment != toDeleteAttachment

                    askResponse.finish()

                return @attachmentsService.delete(@.type, toDeleteAttachment.getIn(['file', 'id'])).then(onSuccess, onError)

    reorderAttachment: (attachment, newIndex) ->
        oldIndex = @.attachments.findIndex (it) -> it == attachment
        return if oldIndex == newIndex

        attachments = @.attachments.remove(oldIndex)
        attachments = attachments.splice(newIndex, 0, attachment)
        attachments = attachments.map (x, i) -> x.setIn(['file', 'order'], i + 1)

        promises = attachments.map (attachment) =>
            patch = {order: attachment.getIn(['file', 'order'])}

            return @attachmentsService.patch(attachment.getIn(['file', 'id']), @.type, patch)

        return Promise.all(promises.toJS()).then () => @.attachments = attachments

    updateAttachment: (toUpdateAttachment) ->
        index = @.attachments.findIndex (attachment) ->
            return attachment.getIn(['file', 'id']) == toUpdateAttachment.getIn(['file', 'id'])

        oldAttachment = @.attachments.get(index)

        patch = taiga.patch(oldAttachment.get('file'), toUpdateAttachment.get('file'))

        return @attachmentsService.patch(toUpdateAttachment.getIn(['file', 'id']), @.type, patch).then () =>
            @.attachments = @.attachments.set(index, toUpdateAttachment)

angular.module("taigaComponents").controller("Attachments2", AttachmentsController2)
