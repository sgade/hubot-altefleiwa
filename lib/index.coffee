# Description
#   Dieckert-OL gets today's menu for the Dieckert Cantina.
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
#
# Notes:
#
# Author:
#   sgade

http = require 'http'
cheerio = require 'cheerio'
entities = require('html-entities').AllHtmlEntities
iconv = new require('iconv-lite')

planEncoding = "CP1252"
planURL = "http://www.speisereise.com/content/speise/kantine_speiseplan.php"

getPlan = (cb) ->
  http.get planURL, (res) ->
    body = null
    res.on 'data', (bodyPart) ->
      partBuffer = new Buffer(bodyPart, planEncoding)
      if !body
        body = partBuffer
      else
        body = Buffer.concat( [ body, partBuffer ] )
    res.on 'error', (err) ->
      cb err, res, null
    res.on 'end', ->
      cb null, res, body

module.exports = (robot) ->

  robot.respond /(feed me)/i, (res) ->

    dayOfTheWeek = new Date().getDay()
    if dayOfTheWeek < 1 || dayOfTheWeek > 5
      res.reply "I'm sorry, food is only served during the week."
      return

    getPlan (err, response, body) ->
      if !!err
        res.reply "I'm sorry, I could not load the plan."
        return

      body = iconv.decode body, planEncoding
      $ = cheerio.load body
      tds = $ "td.speiseplan"

      meals = getMealsForDay dayOfTheWeek, tds

      text = ""
      if meals.length == 0
        text = "Nothing to eat today."
      else
        text = "Today's meals:\n"
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
