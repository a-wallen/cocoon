// Copyright 2022 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:auto_submit/model/auto_submit_query_result.dart' as auto hide PullRequest;
import 'package:auto_submit/service/process_method.dart';
import 'package:auto_submit/service/validation_service.dart';
import 'package:auto_submit/validations/validation.dart';
import 'package:github/github.dart';
import 'package:graphql/client.dart';
import 'package:test/test.dart';

import '../requests/github_webhook_test_data.dart';
import '../src/request_handling/fake_pubsub.dart';
import '../src/service/fake_approver_service.dart';
import '../src/service/fake_config.dart';
import '../src/service/fake_graphql_client.dart';
import '../src/service/fake_github_service.dart';
import '../src/validations/fake_revert.dart';
import '../utilities/utils.dart';
import '../utilities/mocks.dart';

void main() {
  late ValidationService validationService;
  late FakeConfig config;
  late FakeGithubService githubService;
  late FakeGraphQLClient githubGraphQLClient;
  late RepositorySlug slug;

  setUp(() {
    githubGraphQLClient = FakeGraphQLClient();
    githubService = FakeGithubService(client: MockGitHub());
    config = FakeConfig(githubService: githubService, githubGraphQLClient: githubGraphQLClient);
    validationService = ValidationService(config);
    slug = RepositorySlug('flutter', 'cocoon');
  });

  test('Removes label and post comment when no approval', () async {
    final PullRequestHelper flutterRequest = PullRequestHelper(
      prNumber: 0,
      lastCommitHash: oid,
      reviews: <PullRequestReviewHelper>[],
    );
    githubService.checkRunsData = checkRunsMock;
    githubService.createCommentData = createCommentMock;
    final FakePubSub pubsub = FakePubSub();
    final PullRequest pullRequest = generatePullRequest(prNumber: 0, repoName: slug.name);
    unawaited(pubsub.publish('auto-submit-queue-sub', pullRequest));
    final auto.QueryResult queryResult = createQueryResult(flutterRequest);

    await validationService.processPullRequest(
      config: config,
      result: queryResult,
      messagePullRequest: pullRequest,
      ackId: 'test',
      pubsub: pubsub,
    );

    expect(githubService.issueComment, isNotNull);
    expect(githubService.labelRemoved, true);
    assert(pubsub.messagesQueue.isEmpty);
  });

  test('Remove label and post comment when no revert label.', () async {
    final PullRequestHelper flutterRequest = PullRequestHelper(
      prNumber: 0,
      lastCommitHash: oid,
      reviews: <PullRequestReviewHelper>[],
    );
    githubService.checkRunsData = checkRunsMock;
    githubService.createCommentData = createCommentMock;
    final FakePubSub pubsub = FakePubSub();
    final PullRequest pullRequest = generatePullRequest(
      prNumber: 0,
      repoName: slug.name,
    );
    unawaited(pubsub.publish('auto-submit-queue-sub', pullRequest));
    final auto.QueryResult queryResult = createQueryResult(flutterRequest);

    await validationService.processRevertRequest(
      config: config,
      result: queryResult,
      messagePullRequest: pullRequest,
      ackId: 'test',
      pubsub: pubsub,
    );

    expect(githubService.issueComment, isNotNull);
    expect(githubService.labelRemoved, true);
    assert(pubsub.messagesQueue.isEmpty);
  });

  group('Processing revert reqeuests.', () {
    test('Merge valid revert request, issue created and message is acknowledged.', () async {
      githubGraphQLClient.mutateResultForOptions = (MutationOptions options) => createFakeQueryResult();
      final PullRequestHelper flutterRequest = PullRequestHelper(
        prNumber: 0,
        lastCommitHash: oid,
        reviews: <PullRequestReviewHelper>[],
      );

      githubService.checkRunsData = checkRunsMock;
      githubService.createCommentData = createCommentMock;
      final FakePubSub pubsub = FakePubSub();
      final PullRequest pullRequest = generatePullRequest(
        prNumber: 0,
        repoName: slug.name,
        authorAssociation: 'OWNER',
        labelName: 'revert',
        body: 'Reverts flutter/flutter#1234',
      );

      final FakeRevert fakeRevert = FakeRevert(config: config);
      fakeRevert.validationResult = ValidationResult(true, Action.REMOVE_LABEL, '');
      validationService.revertValidation = fakeRevert;
      final FakeApproverService fakeApproverService = FakeApproverService(config);
      validationService.approverService = fakeApproverService;

      final Issue issue = Issue(
        id: 1234,
      );
      githubService.githubIssueMock = issue;

      unawaited(pubsub.publish('auto-submit-queue-sub', pullRequest));
      final auto.QueryResult queryResult = createQueryResult(flutterRequest);

      await validationService.processRevertRequest(
        config: config,
        result: queryResult,
        messagePullRequest: pullRequest,
        ackId: 'test',
        pubsub: pubsub,
      );

      // if the merge is successful we do not remove the label and we do not add a comment to the issue.
      expect(githubService.issueComment, isNull);
      expect(githubService.labelRemoved, false);
      // We acknowledge the issue.
      assert(pubsub.messagesQueue.isEmpty);
    });

    test('Fail to merge non valid revert, issue not created, comment is added and message is acknowledged.', () async {
      githubGraphQLClient.mutateResultForOptions = (MutationOptions options) => createFakeQueryResult();
      final PullRequestHelper flutterRequest = PullRequestHelper(
        prNumber: 0,
        lastCommitHash: oid,
        reviews: <PullRequestReviewHelper>[],
      );

      githubService.checkRunsData = checkRunsMock;
      githubService.createCommentData = createCommentMock;
      final FakePubSub pubsub = FakePubSub();
      final PullRequest pullRequest = generatePullRequest(
        prNumber: 0,
        repoName: slug.name,
        authorAssociation: 'OWNER',
        labelName: 'revert',
        body: 'Reverts flutter/flutter#1234',
      );

      final FakeRevert fakeRevert = FakeRevert(config: config);
      fakeRevert.validationResult = ValidationResult(false, Action.REMOVE_LABEL, '');
      validationService.revertValidation = fakeRevert;
      final FakeApproverService fakeApproverService = FakeApproverService(config);
      validationService.approverService = fakeApproverService;

      unawaited(pubsub.publish('auto-submit-queue-sub', pullRequest));
      final auto.QueryResult queryResult = createQueryResult(flutterRequest);

      await validationService.processRevertRequest(
        config: config,
        result: queryResult,
        messagePullRequest: pullRequest,
        ackId: 'test',
        pubsub: pubsub,
      );

      // if the merge is successful we do not remove the label and we do not add a comment to the issue.
      expect(githubService.issueComment, isNotNull);
      expect(githubService.labelRemoved, true);
      // We acknowledge the issue.
      assert(pubsub.messagesQueue.isEmpty);
    });

    test('Remove label and post comment when unable to process merge.', () async {
      final PullRequestHelper flutterRequest = PullRequestHelper(
        prNumber: 0,
        lastCommitHash: oid,
        reviews: <PullRequestReviewHelper>[],
      );
      githubService.checkRunsData = checkRunsMock;
      githubService.createCommentData = createCommentMock;
      final FakePubSub pubsub = FakePubSub();
      final PullRequest pullRequest = generatePullRequest(
        prNumber: 0,
        repoName: slug.name,
        authorAssociation: 'OWNER',
        labelName: 'revert',
      );

      final FakeRevert fakeRevert = FakeRevert(config: config);
      fakeRevert.validationResult = ValidationResult(true, Action.REMOVE_LABEL, '');
      validationService.revertValidation = fakeRevert;
      final FakeApproverService fakeApproverService = FakeApproverService(config);
      validationService.approverService = fakeApproverService;

      unawaited(pubsub.publish('auto-submit-queue-sub', pullRequest));
      final auto.QueryResult queryResult = createQueryResult(flutterRequest);

      await validationService.processRevertRequest(
        config: config,
        result: queryResult,
        messagePullRequest: pullRequest,
        ackId: 'test',
        pubsub: pubsub,
      );

      expect(githubService.issueComment, isNotNull);
      expect(githubService.labelRemoved, true);
      assert(pubsub.messagesQueue.isEmpty);
    });

    test('Fail to create follow up review issue, comment is added and message is acknowledged.', () async {
      githubGraphQLClient.mutateResultForOptions = (MutationOptions options) => createFakeQueryResult();
      final PullRequestHelper flutterRequest = PullRequestHelper(
        prNumber: 0,
        lastCommitHash: oid,
        reviews: <PullRequestReviewHelper>[],
      );

      githubService.checkRunsData = checkRunsMock;
      githubService.createCommentData = createCommentMock;
      githubService.throwOnCreateIssue = true;
      githubService.useRealComment = true;
      final FakePubSub pubsub = FakePubSub();
      final PullRequest pullRequest = generatePullRequest(
        prNumber: 0,
        repoName: slug.name,
        authorAssociation: 'OWNER',
        labelName: 'revert',
        body: 'Reverts flutter/flutter#1234',
      );

      final FakeRevert fakeRevert = FakeRevert(config: config);
      fakeRevert.validationResult = ValidationResult(true, Action.REMOVE_LABEL, '');
      validationService.revertValidation = fakeRevert;
      final FakeApproverService fakeApproverService = FakeApproverService(config);
      validationService.approverService = fakeApproverService;

      unawaited(pubsub.publish('auto-submit-queue-sub', pullRequest));
      final auto.QueryResult queryResult = createQueryResult(flutterRequest);

      await validationService.processRevertRequest(
        config: config,
        result: queryResult,
        messagePullRequest: pullRequest,
        ackId: 'test',
        pubsub: pubsub,
      );

      // if the merge is successful we do not remove the label and we do not add a comment to the issue.
      expect(githubService.issueComment, isNotNull);
      final IssueComment issueComment = githubService.issueComment!;
      assert(issueComment.body!.contains('create the follow up review issue'));
      expect(githubService.labelRemoved, false);
      // We acknowledge the issue.
      assert(pubsub.messagesQueue.isEmpty);
    });
  });

  group('Process pull request', () {
    test('Should process message when autosubmit label exists and pr is open', () async {
      final PullRequest pullRequest = generatePullRequest(prNumber: 0, repoName: slug.name);
      githubService.pullRequestData = pullRequest;
      final ProcessMethod processMethod = await validationService.processPullRequestMethod(pullRequest);

      expect(processMethod, ProcessMethod.processAutosubmit);
    });

    test('Skip processing message when autosubmit label does not exist anymore', () async {
      final PullRequest pullRequest = generatePullRequest(prNumber: 0, repoName: slug.name);
      pullRequest.labels = <IssueLabel>[];
      githubService.pullRequestData = pullRequest;
      final ProcessMethod processMethod = await validationService.processPullRequestMethod(pullRequest);

      expect(processMethod, ProcessMethod.doNotProcess);
    });

    test('Skip processing message when the pull request is closed', () async {
      final PullRequest pullRequest = generatePullRequest(prNumber: 0, repoName: slug.name);
      pullRequest.state = 'closed';
      githubService.pullRequestData = pullRequest;
      final ProcessMethod processMethod = await validationService.processPullRequestMethod(pullRequest);

      expect(processMethod, ProcessMethod.doNotProcess);
    });

    test('Should process message when revert label exists and pr is open', () async {
      final PullRequest pullRequest = generatePullRequest(prNumber: 0, repoName: slug.name);
      final IssueLabel issueLabel = IssueLabel(name: 'revert');
      pullRequest.labels = <IssueLabel>[issueLabel];
      githubService.pullRequestData = pullRequest;
      final ProcessMethod processMethod = await validationService.processPullRequestMethod(pullRequest);

      expect(processMethod, ProcessMethod.processRevert);
    });

    test('Should process message as revert when revert and autosubmit labels are present and pr is open', () async {
      final PullRequest pullRequest = generatePullRequest(prNumber: 0, repoName: slug.name);
      final IssueLabel issueLabel = IssueLabel(name: 'revert');
      pullRequest.labels!.add(issueLabel);
      githubService.pullRequestData = pullRequest;
      final ProcessMethod processMethod = await validationService.processPullRequestMethod(pullRequest);

      expect(processMethod, ProcessMethod.processRevert);
    });

    test('Skip processing message when revert label exists and pr is closed', () async {
      final PullRequest pullRequest = generatePullRequest(prNumber: 0, repoName: slug.name);
      pullRequest.state = 'closed';
      final IssueLabel issueLabel = IssueLabel(name: 'revert');
      pullRequest.labels = <IssueLabel>[issueLabel];
      githubService.pullRequestData = pullRequest;
      final ProcessMethod processMethod = await validationService.processPullRequestMethod(pullRequest);

      expect(processMethod, ProcessMethod.doNotProcess);
    });
  });
}
