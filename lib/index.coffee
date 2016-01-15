# Description
#   Gets today's menu for the Dieckert Cantina.
#
# Dependencies:
#   "cheerio": "0.19.0"
#   "iconv-lite": "0.4.13"
#   "html-entities": "1.2.0"
#
# Configuration:
#
# Commands:
#   hubot feed me - Replys with today's menu.
#   hubot feed me tomorrow - Replys with tomorrow's menu.
#
# Notes:
#
# Author:
#   sgade

http = require 'http'
cheerio = require 'cheerio'
entities = require('html-entities').AllHtmlEntities
iconv = new require 'iconv-lite'

planEncoding = "CP1252"
planURL = "http://www.speisereise.com/content/speise/kantine_speiseplan.php"

module.exports = (robot) ->

  # We have our own http implementation because of encoding issues
  getPlan = (cb) ->
    # request the page
    http.get planURL, (res) ->
      body = null
      # save all parts of the page
      res.on 'data', (bodyPart) ->
        partBuffer = new Buffer(bodyPart, planEncoding)
        if not body?
          body = partBuffer
        else
          body = Buffer.concat( [ body, partBuffer ] )
      # only call callback when all data is collected
      res.on 'end', ->
        cb null, res, body
      # call callback on error
      res.on 'error', (err) ->
        cb err, res, null


  robot.respond /feed me ?(today|tomorrow|mon|tue|wed|thu|fri)?/i, (res) ->

    day = res.match[1]
    dayOfWeek = textToDayOfWeek day

    if not day? or /today/i.test(day)
      dayOfWeek = new Date().getDay()
    else if /tomorrow/i.test(day)
      dayOfWeek = ( new Date().getDay() + 1 ) % 7
    
    replyForDayOfWeek dayOfWeek, res

  replyForDayOfWeek = (dayOfWeek, res) ->
    if dayOfWeek < 1 || dayOfWeek > 5
      res.reply "I'm sorry, food is only served during the week."
      return

    getPlan (err, response, body) ->
      if err?
        res.reply "I'm sorry, I could not load the plan. (\"" + err + "\")"
        return

      body = iconv.decode body, planEncoding
      $ = cheerio.load body
      tds = $ "td.speiseplan"

      meals = getMealsForDay dayOfWeek, tds

      text = ""
      if meals.length == 0
        text = "Nothing to eat today."
      else
        text = getTextForDayOfWeek(dayOfWeek) + "'s meals:\n"
        for meal in meals
          for i in [0..20]
            text += "-"
          text += "\n" + meal
      text = text.trim()

      res.reply text

  getMealsForDay = (dayOfWeek, tds) ->
    meals = []

    dayTds = tds.slice ( dayOfWeek - 1 ) * 4, dayOfWeek * 4
    if dayTds.length == 0
      return meals

    for i in [0...dayTds.length]
      mealDescription = dayTds.eq(i).html().replace(/<br>/ig, "\n")
      mealDescription = entities.decode mealDescription
      meals.push mealDescription

    return meals

  textToDayOfWeek = (text) ->
    if /mon(day)?/i.test(text)
      1
    else if /tue(sday)?/i.test(text)
      2
    else if /wed(nesday)?/i.test(text)
      3
    else if /thu(rsday)?/i.test(text)
      4
    else if /fri(day)?/i.test(text)
      5
    else if /sat(urday)?/i.test(text)
      6
    else if /sun(day)?/i.test(text)
      0
    else
      -1

  getTextForDayOfWeek = (dayOfWeek) ->
    today = new Date().getDay()
    if today == dayOfWeek
      "Today"
    else if (today+1)%7 == dayOfWeek
      "Tomorrow"
    else
      switch dayOfWeek
        when 0 then "Sunday"
        when 1 then "Monday"
        when 2 then "Tuesday"
        when 3 then "Wednesday"
        when 4 then "Thursday"
        when 5 then "Friday"
        when 6 then "Saturday"
